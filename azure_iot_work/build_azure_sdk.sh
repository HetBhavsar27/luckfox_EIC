#!/usr/bin/env bash

set -euo pipefail

fail()
{
    echo
    echo "ERROR: $*" >&2
    exit 1
}

section()
{
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUCKFOX_SDK="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARENT_DIR="$(cd "${LUCKFOX_SDK}/.." && pwd)"

AZURE_SDK="${AZURE_SDK:-${PARENT_DIR}/azure-iot-sdk-c}"

BUILD_DIR="${SCRIPT_DIR}/azure-build-arm"
INSTALL_DIR="${SCRIPT_DIR}/azure-install-arm"
TOOLCHAIN_FILE="${SCRIPT_DIR}/luckfox-rv1106-toolchain.cmake"

CONFIGURE_LOG="${SCRIPT_DIR}/cmake_configure.log"
BUILD_LOG="${SCRIPT_DIR}/azure_build.log"
INSTALL_LOG="${SCRIPT_DIR}/azure_install.log"

EXPECTED_AZURE_TAG="${EXPECTED_AZURE_TAG:-LTS_03_2025}"
EXPECTED_AZURE_COMMIT="${EXPECTED_AZURE_COMMIT:-79145b2cf2050b3a10d22003156db86f6e9c5c5e}"

section "Azure IoT C SDK cross-build for Luckfox RV1106"

echo "LUCKFOX SDK:    ${LUCKFOX_SDK}"
echo "AZURE SDK:      ${AZURE_SDK}"
echo "WORKSPACE:      ${SCRIPT_DIR}"
echo "TOOLCHAIN FILE: ${TOOLCHAIN_FILE}"

if [ ! -f "${LUCKFOX_SDK}/build.sh" ]; then
    fail "Luckfox SDK root could not be detected"
fi

if [ ! -d "${AZURE_SDK}/.git" ]; then
    fail "Azure SDK repository was not found at ${AZURE_SDK}"
fi

if [ ! -f "${TOOLCHAIN_FILE}" ]; then
    fail "Toolchain file was not found at ${TOOLCHAIN_FILE}"
fi

BUILDROOT_BASE="${LUCKFOX_SDK}/sysdrv/source/buildroot"

if [ ! -d "${BUILDROOT_BASE}" ]; then
    fail "Buildroot directory was not found at ${BUILDROOT_BASE}"
fi

BUILDROOT_DIR="$(
    find "${BUILDROOT_BASE}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'buildroot-*' \
        -print |
    sort -V |
    tail -n 1
)"

if [ -z "${BUILDROOT_DIR}" ]; then
    fail "No Buildroot source directory was found"
fi

BUILDROOT_OUTPUT="${BUILDROOT_DIR}/output"
SYSROOT="${BUILDROOT_OUTPUT}/staging"
TARGET_ROOTFS="${BUILDROOT_OUTPUT}/target"

export LUCKFOX_SDK_ROOT="${LUCKFOX_SDK}"
export LUCKFOX_BUILDROOT_OUTPUT="${BUILDROOT_OUTPUT}"

ACTUAL_AZURE_COMMIT="$(git -C "${AZURE_SDK}" rev-parse HEAD)"
ACTUAL_AZURE_VERSION="$(git -C "${AZURE_SDK}" describe --tags --always)"

if [ "${ACTUAL_AZURE_COMMIT}" != "${EXPECTED_AZURE_COMMIT}" ]; then
    fail "Expected Azure ${EXPECTED_AZURE_TAG}, found ${ACTUAL_AZURE_VERSION}"
fi

if [ -n "$(git -C "${AZURE_SDK}" status --porcelain)" ]; then
    git -C "${AZURE_SDK}" status --short
    fail "Azure SDK working tree is not clean"
fi

if git -C "${AZURE_SDK}" submodule status | grep -qE '^[-+U]'; then
    git -C "${AZURE_SDK}" submodule status
    fail "Azure SDK submodules are not ready"
fi

REQUIRED_TARGET_FILES=(
    "${SYSROOT}/usr/include/openssl/ssl.h"
    "${SYSROOT}/usr/include/openssl/opensslv.h"
    "${SYSROOT}/usr/lib/libssl.so"
    "${SYSROOT}/usr/lib/libcrypto.so"
)

for target_file in "${REQUIRED_TARGET_FILES[@]}"; do
    if [ ! -e "${target_file}" ]; then
        fail "Required target file is missing: ${target_file}"
    fi
done

TOOLCHAIN_DIR="${LUCKFOX_SDK}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
CROSS_PREFIX="${TOOLCHAIN_DIR}/bin/arm-rockchip830-linux-uclibcgnueabihf"

C_COMPILER="${CROSS_PREFIX}-gcc"
CXX_COMPILER="${CROSS_PREFIX}-g++"
CROSS_READELF="${CROSS_PREFIX}-readelf"

if [ ! -x "${C_COMPILER}" ]; then
    fail "ARM C compiler was not found: ${C_COMPILER}"
fi

if [ ! -x "${CXX_COMPILER}" ]; then
    fail "ARM C++ compiler was not found: ${CXX_COMPILER}"
fi

OPENSSL_VERSION="$(
    grep 'OPENSSL_VERSION_TEXT' \
        "${SYSROOT}/usr/include/openssl/opensslv.h" |
    head -n 1 |
    sed 's/^[[:space:]]*//'
)"

section "Detected build environment"

echo "AZURE VERSION:    ${ACTUAL_AZURE_VERSION}"
echo "AZURE COMMIT:     ${ACTUAL_AZURE_COMMIT}"
echo "BUILDROOT:        $(basename "${BUILDROOT_DIR}")"
echo "TARGET TUPLE:     $("${C_COMPILER}" -dumpmachine)"
echo "C COMPILER:       ${C_COMPILER}"
echo "C++ COMPILER:     ${CXX_COMPILER}"
echo "TARGET SYSROOT:   ${SYSROOT}"
echo "TARGET ROOTFS:    ${TARGET_ROOTFS}"
echo "TARGET OPENSSL:   ${OPENSSL_VERSION}"
echo "BUILD DIRECTORY:  ${BUILD_DIR}"
echo "INSTALL DIRECTORY:${INSTALL_DIR}"

section "Requested Azure build options"

echo "CMAKE_BUILD_TYPE=Release"
echo "use_mqtt=ON"
echo "use_amqp=OFF"
echo "use_http=OFF"
echo "use_wsio=OFF"
echo "use_prov_client=OFF"
echo "build_service_client=OFF"
echo "build_provisioning_service_client=OFF"
echo "skip_samples=ON"
echo "BUILD_TESTING=OFF"
echo "use_openssl=ON"
echo "use_installed_dependencies=OFF"
echo "CMAKE_VERBOSE_MAKEFILE=ON"

command rm -rf "${BUILD_DIR}"
command rm -rf "${INSTALL_DIR}"

mkdir -p "${BUILD_DIR}"

section "Configuring Azure IoT C SDK"

if ! cmake \
    -S "${AZURE_SDK}" \
    -B "${BUILD_DIR}" \
    -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -Duse_mqtt=ON \
    -Duse_amqp=OFF \
    -Duse_http=OFF \
    -Duse_wsio=OFF \
    -Duse_prov_client=OFF \
    -Dbuild_service_client=OFF \
    -Dbuild_provisioning_service_client=OFF \
    -Dskip_samples=ON \
    -DBUILD_TESTING=OFF \
    -Duse_openssl=ON \
    -Duse_installed_dependencies=OFF \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    2>&1 | tee "${CONFIGURE_LOG}"
then
    fail "CMake configuration failed. Log: ${CONFIGURE_LOG}"
fi

CMAKE_CACHE="${BUILD_DIR}/CMakeCache.txt"

if [ ! -f "${CMAKE_CACHE}" ]; then
    fail "CMakeCache.txt was not generated"
fi

section "Validating generated configuration"

if grep -qE \
    '/usr/lib/x86_64|/lib/x86_64|x86_64-linux-gnu' \
    "${CMAKE_CACHE}"
then
    grep -E \
        '/usr/lib/x86_64|/lib/x86_64|x86_64-linux-gnu' \
        "${CMAKE_CACHE}"

    fail "Host x86 library paths were detected"
fi

grep -q '^use_mqtt:BOOL=ON' "${CMAKE_CACHE}" ||
    fail "MQTT support is not enabled"

grep -q '^use_amqp:BOOL=OFF' "${CMAKE_CACHE}" ||
    fail "AMQP support is not disabled"

grep -q '^use_http:BOOL=OFF' "${CMAKE_CACHE}" ||
    fail "HTTP support is not disabled"

grep -q '^use_wsio:BOOL=OFF' "${CMAKE_CACHE}" ||
    fail "WebSocket I/O support is not disabled"

grep -q '^use_prov_client:BOOL=OFF' "${CMAKE_CACHE}" ||
    fail "DPS device client is not disabled"

grep -q '^skip_samples:BOOL=ON' "${CMAKE_CACHE}" ||
    fail "Azure samples are not disabled"

grep -q '^BUILD_TESTING:BOOL=OFF' "${CMAKE_CACHE}" ||
    fail "Azure tests are not disabled"

echo "Compiler:"
grep -R \
    'set(CMAKE_C_COMPILER ' \
    "${BUILD_DIR}/CMakeFiles"/*/CMakeCCompiler.cmake |
head -n 1 || true

echo
echo "OpenSSL:"
grep -E \
    '^FIND_PACKAGE_MESSAGE_DETAILS_OpenSSL:' \
    "${CMAKE_CACHE}" || true

echo
echo "Azure feature options:"
grep -E \
    '^(use_mqtt|use_amqp|use_http|use_wsio|use_prov_client|skip_samples|BUILD_TESTING):' \
    "${CMAKE_CACHE}"

echo
echo "PASS: ARM MQTT-only configuration is valid"
echo "PASS: No host x86 library paths were detected"

section "Building Azure IoT C SDK"

if ! cmake --build "${BUILD_DIR}" \
    --parallel "$(nproc)" \
    2>&1 | tee "${BUILD_LOG}"
then
    fail "Azure SDK build failed. Log: ${BUILD_LOG}"
fi

section "Installing Azure headers and libraries"

if ! cmake --install "${BUILD_DIR}" \
    2>&1 | tee "${INSTALL_LOG}"
then
    fail "Azure SDK installation failed. Log: ${INSTALL_LOG}"
fi

REQUIRED_LIBRARIES=(
    "libiothub_client.a"
    "libiothub_client_mqtt_transport.a"
    "libumqtt.a"
    "libaziotsharedutil.a"
    "libparson.a"
)

for library in "${REQUIRED_LIBRARIES[@]}"; do
    library_path="${INSTALL_DIR}/lib/${library}"

    if [ ! -f "${library_path}" ]; then
        fail "Installed library is missing: ${library_path}"
    fi
done

REQUIRED_HEADERS=(
    "azureiot/iothub.h"
    "azureiot/iothub_device_client_ll.h"
    "azureiot/iothubtransportmqtt.h"
    "azureiot/iothub_message.h"
    "azure_c_shared_utility/threadapi.h"
)

for header in "${REQUIRED_HEADERS[@]}"; do
    header_path="${INSTALL_DIR}/include/${header}"

    if [ ! -f "${header_path}" ]; then
        fail "Installed header is missing: ${header_path}"
    fi
done

section "Installed Azure ARM libraries"

for library in "${REQUIRED_LIBRARIES[@]}"; do
    ls -lh "${INSTALL_DIR}/lib/${library}"
done

section "Build completed successfully"

echo "Azure version:     ${ACTUAL_AZURE_VERSION}"
echo "Target tuple:      $("${C_COMPILER}" -dumpmachine)"
echo "Installed headers: ${INSTALL_DIR}/include"
echo "Installed libraries:${INSTALL_DIR}/lib"
echo
echo "Logs:"
echo "  ${CONFIGURE_LOG}"
echo "  ${BUILD_LOG}"
echo "  ${INSTALL_LOG}"
