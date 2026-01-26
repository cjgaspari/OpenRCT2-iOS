#!/bin/bash
# Build libzip for visionOS (arm64)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBZIP_VERSION="1.10.1"
BUILD_DIR="$SCRIPT_DIR/visionos-deps/libzip-build"

BUILD_TARGET="simulator"
for arg in "$@"; do
    case $arg in
        --device) BUILD_TARGET="device" ;;
        --simulator) BUILD_TARGET="simulator" ;;
        --help|-h)
            echo "Usage: $0 [--simulator|--device]"
            exit 0
            ;;
    esac
done

if [[ "$BUILD_TARGET" == "device" ]]; then
    INSTALL_DIR="$SCRIPT_DIR/visionos-deps/libzip-visionos-device"
    SDK_NAME="xros"
    TARGET_SUFFIX=""
    VCPKG_PREFIX="$SCRIPT_DIR/ios-vcpkg/installed/arm64-xros"
else
    INSTALL_DIR="$SCRIPT_DIR/visionos-deps/libzip-visionos"
    SDK_NAME="xrsimulator"
    TARGET_SUFFIX="-simulator"
    VCPKG_PREFIX="$SCRIPT_DIR/ios-vcpkg/installed/arm64-xros-simulator"
fi

# visionOS SDK settings
XROS_SDK=$(xcrun --sdk "$SDK_NAME" --show-sdk-path)
XROS_MIN_VERSION="2.0"
ARCH="arm64"
TARGET_TRIPLE="arm64-apple-xros${XROS_MIN_VERSION}${TARGET_SUFFIX}"

echo "=== Building libzip $LIBZIP_VERSION for visionOS ${BUILD_TARGET} ==="
echo "Using SDK: $XROS_SDK"

# Download if needed
TARBALL="$SCRIPT_DIR/visionos-deps/libzip-$LIBZIP_VERSION.tar.gz"
if [ ! -f "$TARBALL" ]; then
    echo "=== Downloading libzip ==="
    mkdir -p "$SCRIPT_DIR/visionos-deps"
    curl -L -o "$TARBALL" "https://github.com/nih-at/libzip/releases/download/v$LIBZIP_VERSION/libzip-$LIBZIP_VERSION.tar.gz"
fi

# Clean and create directories
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$INSTALL_DIR"

# Extract
cd "$BUILD_DIR"
tar xzf "$TARBALL"
cd "libzip-$LIBZIP_VERSION"
mkdir -p build && cd build

# Create a CMake toolchain file for visionOS
cat > visionos-toolchain.cmake << EOF
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR arm64)

set(CMAKE_OSX_SYSROOT "$XROS_SDK")
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET "2.0")

# Set target triple
set(CMAKE_C_COMPILER_TARGET ${TARGET_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${TARGET_TRIPLE})

# Force compilers to use sysroot
set(CMAKE_C_FLAGS_INIT "-isysroot \${CMAKE_OSX_SYSROOT} -target ${TARGET_TRIPLE} -D_FILE_OFFSET_BITS=64")
set(CMAKE_CXX_FLAGS_INIT "-isysroot \${CMAKE_OSX_SYSROOT} -target ${TARGET_TRIPLE} -D_FILE_OFFSET_BITS=64")

# Prevent CMake from trying to run test executables during configuration
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Pre-set sizeof values that CMake can't detect when cross-compiling
set(SIZEOF_OFF_T 8 CACHE STRING "")
set(HAVE_SIZEOF_OFF_T 1 CACHE STRING "")

# Pre-set features that exist on visionOS
set(HAVE_UNISTD_H 1 CACHE STRING "")
set(HAVE_SYS_TYPES_H 1 CACHE STRING "")

# Disable Windows secure functions that don't exist on visionOS
set(HAVE_MEMCPY_S 0 CACHE STRING "")
set(HAVE_STRNCPY_S 0 CACHE STRING "")
set(HAVE_SNPRINTF_S 0 CACHE STRING "")
set(HAVE_STRERROR_S 0 CACHE STRING "")
set(HAVE_STRERRORLEN_S 0 CACHE STRING "")
set(HAVE_LOCALTIME_S 0 CACHE STRING "")
EOF

# Configure with CMake using toolchain file
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=visionos-toolchain.cmake \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TOOLS=OFF \
    -DBUILD_REGRESS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_DOC=OFF \
    -DENABLE_BZIP2=OFF \
    -DENABLE_LZMA=OFF \
    -DENABLE_ZSTD=OFF \
    -DENABLE_OPENSSL=OFF \
    -DENABLE_GNUTLS=OFF \
    -DENABLE_MBEDTLS=OFF \
    -DENABLE_COMMONCRYPTO=OFF \
    -DZLIB_LIBRARY="$VCPKG_PREFIX/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="$VCPKG_PREFIX/include"

make -j$(sysctl -n hw.ncpu)
make install

echo "=== libzip build complete ==="
echo "Library at: $INSTALL_DIR/lib"
ls -la "$INSTALL_DIR/lib"
