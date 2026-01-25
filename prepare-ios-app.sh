#!/bin/bash
# Prepare OpenRCT2 iOS app bundle for simulator
set -e

WORKSPACE="/Users/cjgaspari/Developer/OpenRCT2-iOS"
BUILD_DIR="$WORKSPACE/build-ios"
APP_BUNDLE="$BUILD_DIR/openrct2.app"
SDL2_FRAMEWORK="$WORKSPACE/ios-deps/SDL2.framework"

echo "=== Preparing OpenRCT2 iOS App Bundle ==="

# Replace the Info.plist with proper iOS version
cp "$WORKSPACE/ios-res/Info.plist" "$APP_BUNDLE/Info.plist"
echo "✓ Updated Info.plist"

# Create Frameworks directory and copy SDL2.framework
mkdir -p "$APP_BUNDLE/Frameworks"
cp -R "$SDL2_FRAMEWORK" "$APP_BUNDLE/Frameworks/"
echo "✓ Copied SDL2.framework"

# Create the data directory structure in the app bundle
# OpenRCT2 looks for data in specific locations, for iOS we'll use Documents folder
# but we need to provide the base data files in the bundle too
mkdir -p "$APP_BUNDLE/data/language"
mkdir -p "$APP_BUNDLE/data/shaders"

# Copy language files
cp "$WORKSPACE/data/language/"*.txt "$APP_BUNDLE/data/language/"
echo "✓ Copied language files"

# Copy shaders
cp "$WORKSPACE/data/shaders/"*.* "$APP_BUNDLE/data/shaders/" 2>/dev/null || echo "No shader files"
echo "✓ Copied shaders"

# Copy scenario_patches if any
if [ -d "$WORKSPACE/data/scenario_patches" ]; then
    mkdir -p "$APP_BUNDLE/data/scenario_patches"
    cp "$WORKSPACE/data/scenario_patches/"* "$APP_BUNDLE/data/scenario_patches/" 2>/dev/null || true
    echo "✓ Copied scenario patches"
fi

# Check for g2.dat - this is the graphics file and is REQUIRED
# It's generated during build or can be copied from an OpenRCT2 release
if [ -f "$BUILD_DIR/g2.dat" ]; then
    cp "$BUILD_DIR/g2.dat" "$APP_BUNDLE/data/"
    echo "✓ Copied g2.dat from build"
elif [ -f "$WORKSPACE/data/g2.dat" ]; then
    cp "$WORKSPACE/data/g2.dat" "$APP_BUNDLE/data/"
    echo "✓ Copied g2.dat from data"
else
    echo "⚠ WARNING: g2.dat not found - you will need to provide this file"
    echo "  Download from OpenRCT2 release or use -DDOWNLOAD_TITLE_SEQUENCES=ON"
fi

# Ad-hoc sign the app (required for simulator)
echo "=== Signing app bundle ==="
codesign --force --deep --sign - "$APP_BUNDLE"
echo "✓ App bundle signed"

echo ""
echo "=== App bundle ready at: $APP_BUNDLE ==="
echo ""
ls -la "$APP_BUNDLE"
echo ""
echo "To run on simulator:"
echo "1. Boot simulator: xcrun simctl boot 'iPhone 16 Pro'"
echo "2. Install app: xcrun simctl install booted '$APP_BUNDLE'"
echo "3. Launch app: xcrun simctl launch booted io.openrct2.OpenRCT2"
