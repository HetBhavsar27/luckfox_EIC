set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(LUCKFOX_SDK "$ENV{HOME}/het/luckfox_EIC")

set(TOOLCHAIN_DIR
    "${LUCKFOX_SDK}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf")

set(CROSS_PREFIX
    "${TOOLCHAIN_DIR}/bin/arm-rockchip830-linux-uclibcgnueabihf")

set(BUILDROOT_OUTPUT
    "${LUCKFOX_SDK}/sysdrv/source/buildroot/buildroot-2023.02.6/output")

set(TARGET_SYSROOT
    "${BUILDROOT_OUTPUT}/staging")

set(CMAKE_C_COMPILER
    "${CROSS_PREFIX}-gcc")

set(CMAKE_CXX_COMPILER
    "${CROSS_PREFIX}-g++")

set(CMAKE_AR
    "${CROSS_PREFIX}-ar")

set(CMAKE_RANLIB
    "${CROSS_PREFIX}-ranlib")

set(CMAKE_STRIP
    "${CROSS_PREFIX}-strip")

set(CMAKE_SYSROOT
    "${TARGET_SYSROOT}")

set(CMAKE_FIND_ROOT_PATH
    "${TARGET_SYSROOT}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(OPENSSL_ROOT_DIR
    "${TARGET_SYSROOT}/usr")

set(OPENSSL_INCLUDE_DIR
    "${TARGET_SYSROOT}/usr/include")

set(OPENSSL_SSL_LIBRARY
    "${TARGET_SYSROOT}/usr/lib/libssl.so")

set(OPENSSL_CRYPTO_LIBRARY
    "${TARGET_SYSROOT}/usr/lib/libcrypto.so")

set(OPENSSL_USE_STATIC_LIBS OFF)

set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)

# Restrict pkg-config searches to the Buildroot target sysroot.
# pkg-config itself runs on the host, but it must return target ARM paths.

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(ENV{PKG_CONFIG_SYSROOT_DIR}
    "${TARGET_SYSROOT}")

set(ENV{PKG_CONFIG_LIBDIR}
    "${TARGET_SYSROOT}/usr/lib/pkgconfig:${TARGET_SYSROOT}/usr/share/pkgconfig")

set(ENV{PKG_CONFIG_PATH}
    "")

set(PKG_CONFIG_USE_CMAKE_PREFIX_PATH OFF)
