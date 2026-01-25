#!/bin/bash
# Build OpenRCT2 for iOS Simulator
set -e

WORKSPACE="/Users/cjgaspari/Developer/OpenRCT2-iOS"
BUILD_DIR="$WORKSPACE/build-ios"
VCPKG_ROOT="$WORKSPACE/ios-vcpkg/installed/arm64-ios-simulator"
ICU_ROOT="$WORKSPACE/ios-deps/icu-ios"
SDL2_FRAMEWORK="$WORKSPACE/ios-deps/SDL2.framework"

# iOS Simulator settings
SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
MIN_IOS="15.0"

echo "=== Building OpenRCT2 for iOS Simulator ==="
echo "SDK: $SDK_PATH"
echo "vcpkg: $VCPKG_ROOT"
echo "ICU: $ICU_ROOT"
echo "SDL2: $SDL2_FRAMEWORK"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Set PKG_CONFIG_PATH to our iOS deps to avoid picking up macOS bundled libs
export PKG_CONFIG_PATH="$VCPKG_ROOT/lib/pkgconfig:$ICU_ROOT/lib/pkgconfig"

# Disable pkg-config to force manual library discovery for iOS
export PKG_CONFIG=/bin/false

# Configure CMake for iOS cross-compilation
cmake "$WORKSPACE" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN_IOS \
    \
    -DCMAKE_PREFIX_PATH="$VCPKG_ROOT;$ICU_ROOT" \
    -DCMAKE_FIND_ROOT_PATH="$VCPKG_ROOT;$ICU_ROOT" \
    \
    -DSDL2_FRAMEWORK_PATH="$SDL2_FRAMEWORK" \
    -DSPEEXDSP_ROOT="$VCPKG_ROOT" \
    \
    -DFREETYPE_LIBRARY="$VCPKG_ROOT/lib/libfreetype.a" \
    -DFREETYPE_INCLUDE_DIRS="$VCPKG_ROOT/include" \
    -DFREETYPE_LIBRARIES="$VCPKG_ROOT/lib/libfreetype.a" \
    -DZLIB_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DZLIB_LIBRARY="$VCPKG_ROOT/lib/libz.a" \
    -DPNG_PNG_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DPNG_LIBRARY="$VCPKG_ROOT/lib/libpng16.a" \
    \
    -DICU_ROOT="$ICU_ROOT" \
    -DICU_INCLUDE_DIR="$ICU_ROOT/include" \
    -DICU_UC_LIBRARY="$ICU_ROOT/lib/libicuuc.a" \
    -DICU_I18N_LIBRARY="$ICU_ROOT/lib/libicui18n.a" \
    -DICU_DATA_LIBRARY="$ICU_ROOT/lib/libicudata.a" \
    \
    -DLIBZIP_LIBRARY="$VCPKG_ROOT/lib/libzip.a" \
    -DLIBZIP_INCLUDE_DIR="$VCPKG_ROOT/include" \
    \
    -DOPENSSL_CRYPTO_LIBRARY="$VCPKG_ROOT/lib/libcrypto.a" \
    \
    -DBZIP2_LIBRARY="$VCPKG_ROOT/lib/libbz2.a" \
    -DBROTLI_DEC_LIBRARY="$VCPKG_ROOT/lib/libbrotlidec.a" \
    -DBROTLI_COMMON_LIBRARY="$VCPKG_ROOT/lib/libbrotlicommon.a" \
    \
    -DZSTD_LIBRARY="$VCPKG_ROOT/lib/libzstd.a" \
    -DZSTD_INCLUDE_DIR="$VCPKG_ROOT/include" \
    \
    -DDISABLE_DISCORD_RPC=ON \
    -DDISABLE_OPENGL=ON \
    -DDISABLE_HTTP=ON \
    -DDISABLE_NETWORK=ON \
    -DDISABLE_FLAC=ON \
    -DDISABLE_VORBIS=ON \
    -DENABLE_SCRIPTING=OFF \
    -DMACOS_USE_DEPENDENCIES=OFF \
    \
    -DCMAKE_BUILD_TYPE=Release

echo "=== CMake configuration complete ==="
echo "To build, run: cmake --build $BUILD_DIR"
