#!/bin/bash
# build-graphics.sh - Build OpenRCT2 graphics (g2.dat, fonts.dat, tracks.dat)
# from the current branch source, for bundling into the visionOS app.
#
# Usage: ./build-graphics.sh [--clean] [--verbose]
#
# --clean    Remove build directory before rebuilding
# --verbose  Show CMake output

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
BUILD_HOST_DIR="$WORKSPACE/build-macos-host"
RESOURCES_DIR="$WORKSPACE/visionos-resources"
CLEAN=false
VERBOSE=false

# Parse args
for arg in "$@"; do
    case $arg in
        --clean) CLEAN=true ;;
        --verbose) VERBOSE=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Builds g2.dat, fonts.dat, and tracks.dat from current branch source."
            echo ""
            echo "Options:"
            echo "  --clean    Delete build directory and rebuild from scratch"
            echo "  --verbose  Show CMake and build output"
            echo ""
            echo "Outputs are copied to: $RESOURCES_DIR"
            exit 0
            ;;
    esac
done

echo "=============================================="
echo "Building OpenRCT2 Graphics (Host Native)"
echo "=============================================="
echo ""

# Check for cmake
if ! command -v cmake &> /dev/null; then
    echo "❌ cmake not found. Please install CMake."
    exit 1
fi

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "Removing existing build directory..."
    rm -rf "$BUILD_HOST_DIR"
fi

# Create build directory
mkdir -p "$BUILD_HOST_DIR"
mkdir -p "$RESOURCES_DIR"

# Configure CMake for the host machine (NOT cross-compiling)
echo "Configuring CMake for host macOS (no visionOS toolchain)..."
cd "$BUILD_HOST_DIR"

CMAKE_ARGS=(
    "-DCMAKE_BUILD_TYPE=Release"
    "-DDISABLE_GUI=ON"  # We only need the CLI for building graphics
    "-DWITH_TESTS=OFF"
)

if [ "$VERBOSE" = false ]; then
    CMAKE_ARGS+=("-Wno-dev")  # Suppress dev warnings
    cmake "${CMAKE_ARGS[@]}" .. > /dev/null
else
    cmake "${CMAKE_ARGS[@]}" ..
fi

echo "✓ CMake configured"

# Build graphics target
echo ""
echo "Building graphics target (g2.dat, fonts.dat, tracks.dat)..."
if [ "$VERBOSE" = false ]; then
    cmake --build . --target graphics -j$(sysctl -n hw.ncpu) > /dev/null 2>&1
else
    cmake --build . --target graphics -j$(sysctl -n hw.ncpu)
fi

# Verify files were created
echo "✓ Graphics built"
echo ""

# Check for output files
MISSING=false
for file in g2.dat fonts.dat tracks.dat; do
    if [ ! -f "$BUILD_HOST_DIR/$file" ]; then
        echo "❌ $file not found in $BUILD_HOST_DIR"
        MISSING=true
    fi
done

if [ "$MISSING" = true ]; then
    echo "Build failed: expected graphics files not found"
    exit 1
fi

# Copy to visionos-resources
echo "Copying graphics files to visionos-resources..."
cp "$BUILD_HOST_DIR/g2.dat" "$RESOURCES_DIR/"
cp "$BUILD_HOST_DIR/fonts.dat" "$RESOURCES_DIR/"
cp "$BUILD_HOST_DIR/tracks.dat" "$RESOURCES_DIR/"
echo "✓ Copied g2.dat, fonts.dat, tracks.dat to $RESOURCES_DIR"

# Summary
echo ""
echo "=============================================="
echo "Graphics Build Complete!"
echo "=============================================="
echo ""
echo "Files in visionos-resources:"
ls -lh "$RESOURCES_DIR"/{g2.dat,fonts.dat,tracks.dat} 2>/dev/null || echo "(files not visible yet)"
echo ""
echo "💡 Next: Build visionOS app in Xcode. Resources will be bundled automatically."
echo ""