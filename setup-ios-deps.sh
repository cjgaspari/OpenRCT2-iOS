#!/bin/bash
# setup-ios-deps.sh - Set up all iOS dependencies for OpenRCT2
# This script installs vcpkg packages, builds SDL2, and builds ICU for iOS Simulator
#
# Usage: ./setup-ios-deps.sh [--skip-vcpkg] [--skip-sdl2] [--skip-icu]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
DEPS_DIR="$WORKSPACE/ios-deps"
VCPKG_DIR="$WORKSPACE/ios-vcpkg"

# Parse arguments
SKIP_VCPKG=false
SKIP_SDL2=false
SKIP_ICU=false

for arg in "$@"; do
    case $arg in
        --skip-vcpkg) SKIP_VCPKG=true ;;
        --skip-sdl2) SKIP_SDL2=true ;;
        --skip-icu) SKIP_ICU=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-vcpkg] [--skip-sdl2] [--skip-icu]"
            echo ""
            echo "Options:"
            echo "  --skip-vcpkg  Skip vcpkg dependency installation"
            echo "  --skip-sdl2   Skip SDL2 framework build"
            echo "  --skip-icu    Skip ICU library build"
            exit 0
            ;;
    esac
done

echo "=============================================="
echo "OpenRCT2 iOS Dependencies Setup"
echo "=============================================="
echo ""
echo "Workspace: $WORKSPACE"
echo "Dependencies: $DEPS_DIR"
echo "vcpkg: $VCPKG_DIR"
echo ""

# Check prerequisites
echo "=== Checking Prerequisites ==="

if ! xcode-select -p &>/dev/null; then
    echo "❌ Xcode command line tools not installed"
    echo "   Run: xcode-select --install"
    exit 1
fi
echo "✓ Xcode command line tools"

if ! command -v cmake &>/dev/null; then
    echo "❌ CMake not found"
    echo "   Run: brew install cmake"
    exit 1
fi
echo "✓ CMake $(cmake --version | head -1)"

SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null || true)
if [ -z "$SDK_PATH" ]; then
    echo "❌ iOS Simulator SDK not found"
    exit 1
fi
echo "✓ iOS Simulator SDK: $SDK_PATH"
echo ""

# Create directories
mkdir -p "$DEPS_DIR"

#######################################
# Step 1: vcpkg Dependencies
#######################################
if [ "$SKIP_VCPKG" = false ]; then
    echo "=== Step 1/3: Installing vcpkg Dependencies ==="
    
    if [ ! -d "$VCPKG_DIR" ]; then
        echo "Cloning vcpkg..."
        git clone https://github.com/microsoft/vcpkg.git "$VCPKG_DIR"
        cd "$VCPKG_DIR"
        ./bootstrap-vcpkg.sh
    else
        echo "vcpkg already exists at $VCPKG_DIR"
        cd "$VCPKG_DIR"
    fi
    
    # List of required packages
    PACKAGES=(
        "zlib:arm64-ios-simulator"
        "zstd:arm64-ios-simulator"
        "libpng:arm64-ios-simulator"
        "freetype:arm64-ios-simulator"
        "speexdsp:arm64-ios-simulator"
        "libzip:arm64-ios-simulator"
        "openssl:arm64-ios-simulator"
        "bzip2:arm64-ios-simulator"
        "brotli:arm64-ios-simulator"
        "nlohmann-json:arm64-ios-simulator"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        echo "Installing $pkg..."
        ./vcpkg install "$pkg"
    done
    
    echo "✓ vcpkg dependencies installed"
    cd "$WORKSPACE"
else
    echo "=== Step 1/3: Skipping vcpkg (--skip-vcpkg) ==="
fi
echo ""

#######################################
# Step 2: SDL2 Framework
#######################################
if [ "$SKIP_SDL2" = false ]; then
    echo "=== Step 2/3: Building SDL2 Framework ==="
    
    if [ -d "$DEPS_DIR/SDL2.framework" ]; then
        echo "SDL2.framework already exists, skipping..."
    else
        cd "$DEPS_DIR"
        
        SDL2_VERSION="2.30.9"
        SDL2_TARBALL="SDL2-${SDL2_VERSION}.tar.gz"
        SDL2_URL="https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/${SDL2_TARBALL}"
        
        if [ ! -d "SDL2-${SDL2_VERSION}" ]; then
            echo "Downloading SDL2 ${SDL2_VERSION}..."
            curl -L "$SDL2_URL" | tar xz
        fi
        
        cd "SDL2-${SDL2_VERSION}/Xcode/SDL"
        
        echo "Building SDL2 for iOS Simulator..."
        xcodebuild -project SDL.xcodeproj \
            -scheme "Framework-iOS" \
            -configuration Release \
            -sdk iphonesimulator \
            -derivedDataPath ./build \
            ONLY_ACTIVE_ARCH=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            -quiet
        
        cp -R ./build/Build/Products/Release-iphonesimulator/SDL2.framework "$DEPS_DIR/"
        
        # Fix SDL2 header include paths - headers use <SDL2/xxx.h> but are in flat Headers dir
        cd "$DEPS_DIR/SDL2.framework/Headers"
        ln -sf . SDL2
        
        echo "✓ SDL2.framework built"
        
        cd "$WORKSPACE"
    fi
else
    echo "=== Step 2/3: Skipping SDL2 (--skip-sdl2) ==="
fi
echo ""

#######################################
# Step 3: ICU Library
#######################################
if [ "$SKIP_ICU" = false ]; then
    echo "=== Step 3/3: Building ICU Library ==="
    
    if [ -d "$DEPS_DIR/icu-ios/lib/libicuuc.a" ]; then
        echo "ICU already built, skipping..."
    else
        cd "$DEPS_DIR"
        
        ICU_VERSION="76-1"
        ICU_TARBALL="icu4c-76_1-src.tgz"
        ICU_URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/${ICU_TARBALL}"
        
        if [ ! -d "icu" ]; then
            echo "Downloading ICU..."
            curl -L "$ICU_URL" | tar xz
        fi
        
        cd icu/source
        
        # Stage 1: Build host tools
        if [ ! -d "build-host" ]; then
            echo "Building ICU host tools (Stage 1)..."
            mkdir -p build-host && cd build-host
            ../configure --disable-samples --disable-tests
            make -j$(sysctl -n hw.ncpu)
            cd ..
        else
            echo "ICU host tools already built"
        fi
        
        # Stage 2: Cross-compile for iOS Simulator
        echo "Cross-compiling ICU for iOS Simulator (Stage 2)..."
        rm -rf build-ios
        mkdir -p build-ios && cd build-ios
        
        MIN_IOS="15.0"
        
        # Note: --disable-tools is critical - ICU tools use system() which is unavailable on iOS
        ../configure \
            --host=arm-apple-darwin \
            --with-cross-build="$(pwd)/../build-host" \
            --enable-static \
            --disable-shared \
            --disable-samples \
            --disable-tests \
            --disable-tools \
            --disable-extras \
            --prefix="$DEPS_DIR/icu-ios" \
            CC="clang -arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS" \
            CXX="clang++ -arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS -std=c++17 -stdlib=libc++" \
            CFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS" \
            CXXFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS -std=c++17 -stdlib=libc++"
        
        make -j$(sysctl -n hw.ncpu)
        make install
        
        echo "✓ ICU built and installed to $DEPS_DIR/icu-ios"
        
        cd "$WORKSPACE"
    fi
else
    echo "=== Step 3/3: Skipping ICU (--skip-icu) ==="
fi
echo ""

#######################################
# Summary
#######################################
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Installed components:"
[ -d "$VCPKG_DIR/installed/arm64-ios-simulator" ] && echo "  ✓ vcpkg packages"
[ -d "$DEPS_DIR/SDL2.framework" ] && echo "  ✓ SDL2.framework"
[ -d "$DEPS_DIR/icu-ios" ] && echo "  ✓ ICU libraries"
echo ""
echo "Next steps:"
echo "  1. Configure CMake:  ./cmake-ios.sh"
echo "  2. Build:            cd build-ios && cmake --build . -j\$(sysctl -n hw.ncpu)"
echo "  3. Create app:       ./prepare-ios-app.sh"
echo ""
