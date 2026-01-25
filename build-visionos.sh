#!/bin/bash
# build-visionos.sh - Build OpenRCT2 for visionOS Simulator
# 
# This script builds the full libopenrct2.a static library for visionOS.
# After building, the library can be linked into the Xcode project.
#
# Usage: ./build-visionos.sh [--skip-deps] [--clean]
#
# Prerequisites:
#   - Xcode with visionOS SDK
#   - vcpkg dependencies (run with --install-deps first time)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
BUILD_DIR="$WORKSPACE/build-visionos"
VCPKG_ROOT="$WORKSPACE/ios-vcpkg"
VCPKG_INSTALLED="$VCPKG_ROOT/installed/arm64-xros-simulator"
ICU_ROOT="$WORKSPACE/ios-deps/icu-visionos"
TRIPLET="arm64-xros-simulator"

# Parse arguments
SKIP_DEPS=false
CLEAN_BUILD=false
INSTALL_DEPS=false

for arg in "$@"; do
    case $arg in
        --skip-deps) SKIP_DEPS=true ;;
        --clean) CLEAN_BUILD=true ;;
        --install-deps) INSTALL_DEPS=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-deps     Skip vcpkg dependency check"
            echo "  --install-deps  Install vcpkg dependencies (first time setup)"
            echo "  --clean         Clean build directory before building"
            exit 0
            ;;
    esac
done

echo "=============================================="
echo "Building OpenRCT2 for visionOS Simulator"
echo "=============================================="
echo ""

# Check for Xcode and visionOS SDK
if ! xcrun --sdk xrossimulator --show-sdk-path &>/dev/null; then
    echo "❌ visionOS Simulator SDK not found!"
    echo "   Install visionOS platform in Xcode (Xcode > Settings > Platforms)"
    exit 1
fi

XROS_SDK=$(xcrun --sdk xrossimulator --show-sdk-path)
echo "✓ visionOS Simulator SDK: $XROS_SDK"

# Install vcpkg dependencies
if [ "$INSTALL_DEPS" = true ]; then
    echo ""
    echo "=== Installing vcpkg Dependencies ==="
    
    cd "$VCPKG_ROOT"
    
    # Bootstrap vcpkg if needed
    if [ ! -f "./vcpkg" ]; then
        ./bootstrap-vcpkg.sh
    fi
    
    PACKAGES=(
        "zlib:$TRIPLET"
        "zstd:$TRIPLET"
        "libpng:$TRIPLET"
        "freetype:$TRIPLET"
        "libzip:$TRIPLET"
        "openssl:$TRIPLET"
        "bzip2:$TRIPLET"
        "brotli:$TRIPLET"
    )
    
    for pkg in "${PACKAGES[@]}"; do
        echo "Installing $pkg..."
        ./vcpkg install "$pkg" --overlay-triplets=triplets/community || {
            echo "⚠ Failed to install $pkg - may need manual intervention"
        }
    done
    
    echo "✓ Dependencies installed"
    cd "$WORKSPACE"
fi

# Check dependencies exist
if [ "$SKIP_DEPS" = false ]; then
    if [ ! -d "$VCPKG_INSTALLED/lib" ]; then
        echo ""
        echo "⚠ vcpkg dependencies not found at $VCPKG_INSTALLED"
        echo "   Run with --install-deps to install them, or --skip-deps to skip check"
        echo ""
        echo "   Attempting to use iOS Simulator dependencies as fallback..."
        
        IOS_VCPKG="$VCPKG_ROOT/installed/arm64-ios-simulator"
        if [ -d "$IOS_VCPKG/lib" ]; then
            echo "   Found iOS Simulator dependencies, using those"
            VCPKG_INSTALLED="$IOS_VCPKG"
        else
            echo "❌ No dependencies found. Run: ./build-visionos.sh --install-deps"
            exit 1
        fi
    fi
    echo "✓ Using dependencies from: $VCPKG_INSTALLED"
fi

# Check ICU
if [ ! -d "$ICU_ROOT" ]; then
    echo ""
    echo "⚠ ICU for visionOS not found at $ICU_ROOT"
    echo "   Checking for iOS ICU as fallback..."
    
    IOS_ICU="$WORKSPACE/ios-deps/icu-ios"
    if [ -d "$IOS_ICU" ]; then
        echo "   Found iOS ICU"
        ICU_ROOT="$IOS_ICU"
    else
        echo "⚠ ICU not found - build may fail for localization features"
        ICU_ROOT=""
    fi
fi

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo ""
    echo "=== Cleaning Build Directory ==="
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo ""
echo "=== Configuring CMake ==="

CMAKE_ARGS=(
    "$WORKSPACE"
    "-DCMAKE_TOOLCHAIN_FILE=$WORKSPACE/cmake/visionos-simulator.toolchain.cmake"
    "-DCMAKE_BUILD_TYPE=Release"
    
    # Dependency paths
    "-DCMAKE_PREFIX_PATH=$VCPKG_INSTALLED"
    "-DCMAKE_FIND_ROOT_PATH=$VCPKG_INSTALLED"
    
    # Library locations
    "-DFREETYPE_LIBRARY=$VCPKG_INSTALLED/lib/libfreetype.a"
    "-DFREETYPE_INCLUDE_DIRS=$VCPKG_INSTALLED/include"
    "-DZLIB_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    "-DZLIB_LIBRARY=$VCPKG_INSTALLED/lib/libz.a"
    "-DPNG_PNG_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    "-DPNG_LIBRARY=$VCPKG_INSTALLED/lib/libpng16.a"
    "-DLIBZIP_LIBRARY=$VCPKG_INSTALLED/lib/libzip.a"
    "-DLIBZIP_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    "-DOPENSSL_CRYPTO_LIBRARY=$VCPKG_INSTALLED/lib/libcrypto.a"
    "-DBZIP2_LIBRARY=$VCPKG_INSTALLED/lib/libbz2.a"
    "-DZSTD_LIBRARY=$VCPKG_INSTALLED/lib/libzstd.a"
    "-DZSTD_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    
    # Disable SDL/GUI features (using native visionOS rendering)
    "-DDISABLE_GUI=ON"
    "-DDISABLE_SDL=ON"
    "-DDISABLE_DISCORD_RPC=ON"
    "-DDISABLE_OPENGL=ON"
    "-DDISABLE_HTTP=ON"
    "-DDISABLE_NETWORK=ON"
    "-DDISABLE_FLAC=ON"
    "-DDISABLE_VORBIS=ON"
    "-DENABLE_SCRIPTING=OFF"
    
    # Skip downloads (assets managed separately)
    "-DMACOS_USE_DEPENDENCIES=OFF"
    "-DDOWNLOAD_TITLE_SEQUENCES=OFF"
    "-DDOWNLOAD_OBJECTS=OFF"
    "-DDOWNLOAD_OPENSFX=OFF"
    "-DDOWNLOAD_OPENMSX=OFF"
)

# Add ICU if available
if [ -n "$ICU_ROOT" ] && [ -d "$ICU_ROOT" ]; then
    CMAKE_ARGS+=(
        "-DICU_ROOT=$ICU_ROOT"
        "-DICU_INCLUDE_DIR=$ICU_ROOT/include"
    )
fi

cmake "${CMAKE_ARGS[@]}"

# Build the library
echo ""
echo "=== Building libopenrct2.a ==="

NPROC=$(sysctl -n hw.ncpu)
cmake --build . --target libopenrct2 -j"$NPROC"

# Check if build succeeded
if [ ! -f "$BUILD_DIR/libopenrct2.a" ]; then
    echo "❌ Build failed - libopenrct2.a not found"
    exit 1
fi

echo ""
echo "=============================================="
echo "Build Successful!"
echo "=============================================="
echo ""
echo "Library: $BUILD_DIR/libopenrct2.a"
echo ""
echo "Next steps:"
echo "  1. Add library to Xcode project:"
echo "     - Add libopenrct2.a to 'Link Binary With Libraries'"
echo "     - Add dependency .a files from $VCPKG_INSTALLED/lib"
echo ""
echo "  2. Add OPENRCT2_FULL_CONTEXT=1 to preprocessor definitions"
echo ""
echo "  3. Run ./prepare-visionos-app.sh to bundle game assets"
echo ""
