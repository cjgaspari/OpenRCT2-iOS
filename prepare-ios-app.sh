#!/bin/bash
# prepare-ios-app.sh - Create iOS app bundle for OpenRCT2
# This script creates the .app bundle structure and copies all required files
#
# Usage: ./prepare-ios-app.sh [--skip-data] [--download-data]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
BUILD_DIR="$WORKSPACE/build-ios"
APP_BUNDLE="$BUILD_DIR/openrct2.app"
SDL2_FRAMEWORK="$WORKSPACE/ios-deps/SDL2.framework"

# Parse arguments
SKIP_DATA=false
FORCE_DOWNLOAD=false

for arg in "$@"; do
    case $arg in
        --skip-data) SKIP_DATA=true ;;
        --download-data) FORCE_DOWNLOAD=true ;;
        --help|-h)
            echo "Usage: $0 [--skip-data] [--download-data]"
            echo ""
            echo "Options:"
            echo "  --skip-data      Skip copying OpenRCT2 data files (g2.dat, objects, etc.)"
            echo "  --download-data  Force download from GitHub even if local install exists"
            exit 0
            ;;
    esac
done

echo "=============================================="
echo "Preparing OpenRCT2 iOS App Bundle"
echo "=============================================="
echo ""

# Check prerequisites
if [ ! -f "$BUILD_DIR/openrct2" ]; then
    echo "❌ openrct2 executable not found in $BUILD_DIR"
    echo "   Build OpenRCT2 first: cd build-ios && cmake --build . -j\$(sysctl -n hw.ncpu)"
    exit 1
fi

if [ ! -d "$SDL2_FRAMEWORK" ]; then
    echo "❌ SDL2.framework not found at $SDL2_FRAMEWORK"
    echo "   Run ./setup-ios-deps.sh first"
    exit 1
fi

# Create app bundle structure
echo "=== Creating App Bundle Structure ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Frameworks"

# Copy executable
cp "$BUILD_DIR/openrct2" "$APP_BUNDLE/"
echo "✓ Copied openrct2 executable"

# Copy Info.plist
if [ -f "$WORKSPACE/ios-res/Info.plist" ]; then
    cp "$WORKSPACE/ios-res/Info.plist" "$APP_BUNDLE/"
    echo "✓ Copied Info.plist"
else
    echo "⚠ Info.plist not found at ios-res/Info.plist"
fi

# Copy SDL2 framework
cp -R "$SDL2_FRAMEWORK" "$APP_BUNDLE/Frameworks/"
echo "✓ Copied SDL2.framework"

# Copy data files from source (language, shaders, etc.)
echo ""
echo "=== Copying Source Data Files ==="

if [ -d "$WORKSPACE/data/language" ]; then
    cp -R "$WORKSPACE/data/language" "$APP_BUNDLE/"
    echo "✓ Copied language files"
fi

if [ -d "$WORKSPACE/data/shaders" ]; then
    cp -R "$WORKSPACE/data/shaders" "$APP_BUNDLE/"
    echo "✓ Copied shaders"
fi

if [ -d "$WORKSPACE/data/scenario_patches" ]; then
    cp -R "$WORKSPACE/data/scenario_patches" "$APP_BUNDLE/"
    echo "✓ Copied scenario patches"
fi

# Copy OpenRCT2 data files (g2.dat, objects, sequences, etc.)
if [ "$SKIP_DATA" = false ]; then
    echo ""
    echo "=== Copying OpenRCT2 Data Files ==="
    
    DATA_SOURCE=""
    
    # Check for local OpenRCT2 installation first (unless --download-data specified)
    if [ "$FORCE_DOWNLOAD" = false ] && [ -d "/Applications/OpenRCT2.app/Contents/Resources" ]; then
        DATA_SOURCE="/Applications/OpenRCT2.app/Contents/Resources"
        echo "Found local OpenRCT2 installation"
    fi
    
    # If no local install, download from GitHub
    if [ -z "$DATA_SOURCE" ]; then
        echo "No local OpenRCT2 found, downloading from GitHub..."
        
        RELEASE_VERSION="0.4.30"
        RELEASE_URL="https://github.com/OpenRCT2/OpenRCT2/releases/download/v${RELEASE_VERSION}/OpenRCT2-v${RELEASE_VERSION}-macos-universal.zip"
        
        cd "$BUILD_DIR"
        curl -L -o OpenRCT2-macos.zip "$RELEASE_URL"
        unzip -q -o OpenRCT2-macos.zip -d extract_temp
        
        DATA_SOURCE="$BUILD_DIR/extract_temp/OpenRCT2.app/Contents/Resources"
    fi
    
    # Copy data files
    if [ -d "$DATA_SOURCE" ]; then
        [ -f "$DATA_SOURCE/g2.dat" ] && cp "$DATA_SOURCE/g2.dat" "$APP_BUNDLE/" && echo "✓ Copied g2.dat"
        [ -f "$DATA_SOURCE/fonts.dat" ] && cp "$DATA_SOURCE/fonts.dat" "$APP_BUNDLE/" && echo "✓ Copied fonts.dat"
        [ -d "$DATA_SOURCE/object" ] && cp -R "$DATA_SOURCE/object" "$APP_BUNDLE/" && echo "✓ Copied objects"
        [ -d "$DATA_SOURCE/sequence" ] && cp -R "$DATA_SOURCE/sequence" "$APP_BUNDLE/" && echo "✓ Copied sequences"
        [ -d "$DATA_SOURCE/assetpack" ] && cp -R "$DATA_SOURCE/assetpack" "$APP_BUNDLE/" && echo "✓ Copied assetpacks"
    fi
    
    # Clean up downloaded files
    if [ -d "$BUILD_DIR/extract_temp" ]; then
        rm -rf "$BUILD_DIR/extract_temp" "$BUILD_DIR/OpenRCT2-macos.zip"
        echo "✓ Cleaned up temporary files"
    fi
else
    echo ""
    echo "=== Skipping Data Files (--skip-data) ==="
fi

# Sign the app bundle
echo ""
echo "=== Signing App Bundle ==="
codesign --force --sign - --deep "$APP_BUNDLE"
echo "✓ App bundle signed"

# Summary
echo ""
echo "=============================================="
echo "App Bundle Ready!"
echo "=============================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
ls -la "$APP_BUNDLE"
echo ""
echo "To run on iOS Simulator:"
echo "  xcrun simctl boot 'iPhone Air'"
echo "  xcrun simctl install booted '$APP_BUNDLE'"
echo "  xcrun simctl launch booted io.openrct2.OpenRCT2"
echo ""

