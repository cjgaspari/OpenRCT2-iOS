#!/bin/bash
# build-ios.sh - Build OpenRCT2 for iOS
# This script attempts to configure OpenRCT2 for iOS using CMake

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ORCT2_ROOT="$SCRIPT_DIR"
BUILD_DIR="$ORCT2_ROOT/build-ios"
DEPS_DIR="$ORCT2_ROOT/ios-deps"
SDL2_FRAMEWORK="$DEPS_DIR/SDL2.framework"

echo "=========================================="
echo "OpenRCT2 iOS Build Script"
echo "=========================================="
echo ""
echo "Prerequisites:"
echo "  - Xcode and command line tools installed"
echo "  - SDL2.framework built for iOS (simulator)"
echo ""

# Check for Xcode
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode command line tools not installed"
    echo "Run: xcode-select --install"
    exit 1
fi

# Check for SDL2.framework
if [ ! -d "$SDL2_FRAMEWORK" ]; then
    echo "Error: SDL2.framework not found at $SDL2_FRAMEWORK"
    echo ""
    echo "Build SDL2 for iOS first:"
    echo "  cd $DEPS_DIR/SDL2-*/Xcode/SDL/"
    echo "  xcodebuild -scheme 'Framework-iOS' -sdk iphonesimulator"
    exit 1
fi

echo "SDL2.framework found: $SDL2_FRAMEWORK"

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ""
echo "Configuring CMake for iOS Simulator..."
echo ""

# Set up iOS cross-compilation
export CMAKE_OSX_SYSROOT="iphonesimulator"
export CMAKE_OSX_ARCHITECTURES="arm64;x86_64"

# CMake configuration for iOS
# Note: This will fail without all dependencies, but will show what's needed
cmake "$ORCT2_ROOT" \
    -G "Unix Makefiles" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DDISABLE_DISCORD_RPC=ON \
    -DDISABLE_HTTP=ON \
    -DDISABLE_NETWORK=ON \
    -DDISABLE_OPENGL=ON \
    -DDISABLE_VERSION_CHECKER=ON \
    -DDISABLE_GUI=OFF \
    -DMACOS_USE_DEPENDENCIES=OFF \
    -DMACOS_BUNDLE=OFF \
    -DDOWNLOAD_TITLE_SEQUENCES=OFF \
    -DDOWNLOAD_OBJECTS=OFF \
    -DDOWNLOAD_OPENSFX=OFF \
    -DDOWNLOAD_OPENMSX=OFF \
    -DSDL2_DIR="$DEPS_DIR" \
    -DCMAKE_PREFIX_PATH="$DEPS_DIR" \
    -DCMAKE_FRAMEWORK_PATH="$DEPS_DIR" \
    -DCMAKE_FIND_FRAMEWORK=FIRST \
    2>&1

echo ""
echo "=========================================="
echo "CMake configuration attempted."
echo "=========================================="
echo ""
echo "If successful, build with:"
echo "  cmake --build . --parallel"
echo ""
echo "If there are missing dependencies, you need to build them for iOS:"
echo "  - ICU (Unicode support)"
echo "  - zlib (compression)"  
echo "  - zstd (Zstandard compression)"
echo "  - libpng (PNG images)"
echo "  - freetype (fonts)"
echo "  - speexdsp (audio resampling)"
echo "  - libvorbis/FLAC (audio - optional)"
echo ""

