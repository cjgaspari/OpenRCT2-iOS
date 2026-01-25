#!/bin/bash
# Build ICU for visionOS Simulator (arm64)
# This script builds ICU with proper visionOS SDK settings
# Note: Using ICU 76-1 to match libopenrct2.a which was built with ICU 76

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICU_VERSION="76-1"
ICU_TARBALL="$SCRIPT_DIR/visionos-deps/icu4c-76-1-src.tgz"
BUILD_DIR="$SCRIPT_DIR/visionos-deps/icu-build"

# Download ICU 76 if not present
if [ ! -f "$ICU_TARBALL" ]; then
    echo "=== Downloading ICU $ICU_VERSION ==="
    mkdir -p "$SCRIPT_DIR/visionos-deps"
    curl -L -o "$ICU_TARBALL" "https://github.com/unicode-org/icu/releases/download/release-76-1/icu4c-76_1-src.tgz"
fi
HOST_BUILD_DIR="$BUILD_DIR/host"
CROSS_BUILD_DIR="$BUILD_DIR/visionos-sim"
INSTALL_DIR="$SCRIPT_DIR/visionos-deps/icu-visionos"

# visionOS SDK settings
XROS_SDK=$(xcrun --sdk xrsimulator --show-sdk-path)
XROS_MIN_VERSION="2.0"
ARCH="arm64"

echo "=== Building ICU $ICU_VERSION for visionOS Simulator ==="
echo "SDK: $XROS_SDK"
echo "Install dir: $INSTALL_DIR"

# Clean and create directories
rm -rf "$BUILD_DIR" "$INSTALL_DIR"
mkdir -p "$BUILD_DIR" "$HOST_BUILD_DIR" "$CROSS_BUILD_DIR" "$INSTALL_DIR"

# Extract ICU
echo "=== Extracting ICU sources ==="
cd "$BUILD_DIR"
tar xzf "$ICU_TARBALL"

ICU_SOURCE="$BUILD_DIR/icu/source"

# Step 1: Build host ICU (needed for cross-compilation tools)
echo "=== Building host ICU (for cross-compilation tools) ==="
cd "$HOST_BUILD_DIR"

"$ICU_SOURCE/configure" \
    --prefix="$HOST_BUILD_DIR/install" \
    --disable-samples \
    --disable-tests \
    --enable-static \
    --disable-shared

make -j$(sysctl -n hw.ncpu)
make install

# Step 2: Build visionOS Simulator ICU
echo "=== Building visionOS Simulator ICU ==="
cd "$CROSS_BUILD_DIR"

# Set up cross-compilation environment - use raw clang with proper flags
export CC="$(xcrun --sdk xrsimulator -f clang) -arch $ARCH -isysroot $XROS_SDK -target arm64-apple-xros$XROS_MIN_VERSION-simulator"
export CXX="$(xcrun --sdk xrsimulator -f clang++) -arch $ARCH -isysroot $XROS_SDK -target arm64-apple-xros$XROS_MIN_VERSION-simulator -stdlib=libc++ -std=c++17"
export AR="$(xcrun --sdk xrsimulator -f ar)"
export RANLIB="$(xcrun --sdk xrsimulator -f ranlib)"
export STRIP="$(xcrun --sdk xrsimulator -f strip)"

# Minimal compiler flags (main flags are in CC/CXX)
export CFLAGS="-O2"
export CXXFLAGS="-O2"
export LDFLAGS=""

"$ICU_SOURCE/configure" \
    --host=aarch64-apple-darwin \
    --prefix="$INSTALL_DIR" \
    --with-cross-build="$HOST_BUILD_DIR" \
    --disable-samples \
    --disable-tests \
    --enable-static \
    --disable-shared \
    --disable-dyload \
    --disable-extras \
    --disable-icuio \
    --with-data-packaging=static

make -j$(sysctl -n hw.ncpu)
make install

echo "=== ICU build complete ==="
echo "Libraries installed to: $INSTALL_DIR/lib"
ls -la "$INSTALL_DIR/lib"

echo ""
echo "To use in Xcode, add to xcconfig:"
echo "LIBRARY_SEARCH_PATHS = \$(inherited) \$(SRCROOT)/visionos-deps/icu-visionos/lib"
echo "OTHER_LDFLAGS = \$(inherited) -licuuc -licui18n -licudata"
