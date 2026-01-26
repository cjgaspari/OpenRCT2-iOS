#!/bin/bash
# prepare-visionos-app.sh - Prepare visionOS app bundle with OpenRCT2 assets
#
# This script copies required game assets into the visionOS app bundle:
# - g2.dat (OpenRCT2 graphics)
# - language files
# - objects, sequences, assetpacks
#
# The RCT2 base game files (g1.dat from RCT2) must be provided by the user
# via the Documents/OpenRCT2/rct2 folder on the device.
#
# Usage: ./prepare-visionos-app.sh [--download]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
RESOURCES_DIR="$WORKSPACE/visionos-resources"

# Parse arguments
FORCE_DOWNLOAD=false

for arg in "$@"; do
    case $arg in
        --download) FORCE_DOWNLOAD=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Prepares OpenRCT2 assets for the visionOS app bundle."
            echo ""
            echo "Options:"
            echo "  --download    Force download from GitHub even if local install exists"
            echo ""
            echo "Assets are copied to: $RESOURCES_DIR"
            echo ""
            echo "After running, add this folder to your Xcode project's"
            echo "'Copy Bundle Resources' build phase."
            exit 0
            ;;
    esac
done

echo "=============================================="
echo "Preparing OpenRCT2 visionOS Assets"
echo "=============================================="
echo ""

# Create resources directory
mkdir -p "$RESOURCES_DIR"

# Copy data files from source
echo "=== Copying Source Data Files ==="

if [ -d "$WORKSPACE/data/language" ]; then
    cp -R "$WORKSPACE/data/language" "$RESOURCES_DIR/"
    echo "✓ Copied language files"
fi

if [ -d "$WORKSPACE/data/shaders" ]; then
    cp -R "$WORKSPACE/data/shaders" "$RESOURCES_DIR/"
    echo "✓ Copied shaders"
fi

if [ -d "$WORKSPACE/data/scenario_patches" ]; then
    cp -R "$WORKSPACE/data/scenario_patches" "$RESOURCES_DIR/"
    echo "✓ Copied scenario patches"
fi

# Get OpenRCT2 data files (g2.dat, objects, etc.)
echo ""
echo "=== Getting OpenRCT2 Data Files ==="

DATA_SOURCE=""
BUILD_HOST_GRAPHICS="$WORKSPACE/build-macos-host"

# Priority 1: Use freshly built graphics from build-macos-host (from build-graphics.sh)
if [ -f "$BUILD_HOST_GRAPHICS/g2.dat" ] && [ -f "$BUILD_HOST_GRAPHICS/fonts.dat" ] && [ -f "$BUILD_HOST_GRAPHICS/tracks.dat" ]; then
    echo "✓ Using graphics built from current branch source ($BUILD_HOST_GRAPHICS)"
    cp "$BUILD_HOST_GRAPHICS/g2.dat" "$RESOURCES_DIR/"
    cp "$BUILD_HOST_GRAPHICS/fonts.dat" "$RESOURCES_DIR/"
    cp "$BUILD_HOST_GRAPHICS/tracks.dat" "$RESOURCES_DIR/"
    echo "✓ Copied g2.dat, fonts.dat, tracks.dat (from build-graphics.sh)"
    
    # Still need objects/sequences/assetpacks from a data source
    DATA_SOURCE_FOR_EXTRAS=""
    if [ "$FORCE_DOWNLOAD" = false ] && [ -d "/Applications/OpenRCT2.app/Contents/Resources" ]; then
        DATA_SOURCE_FOR_EXTRAS="/Applications/OpenRCT2.app/Contents/Resources"
    fi
    
    if [ -z "$DATA_SOURCE_FOR_EXTRAS" ]; then
        echo ""
        echo "Downloading OpenRCT2 data for objects/sequences..."
        RELEASE_VERSION="0.4.30"
        RELEASE_URL="https://github.com/OpenRCT2/OpenRCT2/releases/download/v${RELEASE_VERSION}/OpenRCT2-v${RELEASE_VERSION}-macos-universal.zip"
        
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        echo "Downloading v$RELEASE_VERSION..."
        curl -L -o OpenRCT2-macos.zip "$RELEASE_URL"
        echo "Extracting..."
        unzip -q OpenRCT2-macos.zip
        DATA_SOURCE_FOR_EXTRAS="$TEMP_DIR/OpenRCT2.app/Contents/Resources"
        cd "$WORKSPACE"
    fi
    
    # Copy additional data files
    if [ -d "$DATA_SOURCE_FOR_EXTRAS" ]; then
        [ -d "$DATA_SOURCE_FOR_EXTRAS/object" ] && cp -R "$DATA_SOURCE_FOR_EXTRAS/object" "$RESOURCES_DIR/" && echo "✓ Copied objects"
        [ -d "$DATA_SOURCE_FOR_EXTRAS/sequence" ] && cp -R "$DATA_SOURCE_FOR_EXTRAS/sequence" "$RESOURCES_DIR/" && echo "✓ Copied sequences"
        [ -d "$DATA_SOURCE_FOR_EXTRAS/assetpack" ] && cp -R "$DATA_SOURCE_FOR_EXTRAS/assetpack" "$RESOURCES_DIR/" && echo "✓ Copied assetpacks"
    fi
else
    echo "⚠ Graphics not found in build-macos-host/"
    echo "  Run ./build-graphics.sh to build from current branch source"
    echo "  Falling back to local install or download..."
    
    # Priority 2: Check for local OpenRCT2 installation
    if [ "$FORCE_DOWNLOAD" = false ] && [ -d "/Applications/OpenRCT2.app/Contents/Resources" ]; then
        DATA_SOURCE="/Applications/OpenRCT2.app/Contents/Resources"
        echo "Found local OpenRCT2 installation at $DATA_SOURCE"
    fi
    
    # Priority 3: Download from GitHub if no local install
    if [ -z "$DATA_SOURCE" ]; then
        echo "Downloading OpenRCT2 data from GitHub..."
        
        RELEASE_VERSION="0.4.30"
        RELEASE_URL="https://github.com/OpenRCT2/OpenRCT2/releases/download/v${RELEASE_VERSION}/OpenRCT2-v${RELEASE_VERSION}-macos-universal.zip"
        
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        echo "Downloading v$RELEASE_VERSION..."
        curl -L -o OpenRCT2-macos.zip "$RELEASE_URL"
        
        echo "Extracting..."
        unzip -q OpenRCT2-macos.zip
        
        DATA_SOURCE="$TEMP_DIR/OpenRCT2.app/Contents/Resources"
        cd "$WORKSPACE"
    fi
    
    # Copy all data files from fallback source
    if [ -d "$DATA_SOURCE" ]; then
        [ -f "$DATA_SOURCE/g2.dat" ] && cp "$DATA_SOURCE/g2.dat" "$RESOURCES_DIR/" && echo "✓ Copied g2.dat"
        [ -f "$DATA_SOURCE/fonts.dat" ] && cp "$DATA_SOURCE/fonts.dat" "$RESOURCES_DIR/" && echo "✓ Copied fonts.dat"
        [ -f "$DATA_SOURCE/tracks.dat" ] && cp "$DATA_SOURCE/tracks.dat" "$RESOURCES_DIR/" && echo "✓ Copied tracks.dat"
        [ -d "$DATA_SOURCE/object" ] && cp -R "$DATA_SOURCE/object" "$RESOURCES_DIR/" && echo "✓ Copied objects"
        [ -d "$DATA_SOURCE/sequence" ] && cp -R "$DATA_SOURCE/sequence" "$RESOURCES_DIR/" && echo "✓ Copied sequences"
        [ -d "$DATA_SOURCE/assetpack" ] && cp -R "$DATA_SOURCE/assetpack" "$RESOURCES_DIR/" && echo "✓ Copied assetpacks"
    else
        echo "⚠ Could not find data source"
    fi
fi

# Check for RCT2_PATH environment variable override
if [ -n "$RCT2_PATH" ] && [ -f "$RCT2_PATH/g1.dat" ]; then
    echo ""
    echo "Using RCT2_PATH override: $RCT2_PATH"
    mkdir -p "$RESOURCES_DIR/rct2/Data"
    for f in g1.dat CSS1.DAT CSS2.DAT CSS4.DAT CSS5.DAT CSS6.DAT CSS7.DAT CSS8.DAT CSS9.DAT; do
        [ -f "$RCT2_PATH/$f" ] && cp "$RCT2_PATH/$f" "$RESOURCES_DIR/rct2/Data/" && echo "✓ Copied $f"
    done
fi

# Clean up temp directory
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    echo "✓ Cleaned up temporary files"
fi

# Create Info.plist for visionOS
echo ""
echo "=== Creating visionOS Info.plist ==="

# Create visionos-res directory if it doesn't exist
mkdir -p "$WORKSPACE/visionos-res"

cat > "$WORKSPACE/visionos-res/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>OpenRCT2</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.4.30</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>LSRequiresIPhoneOS</key>
    <false/>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <true/>
        <key>UISceneConfigurations</key>
        <dict/>
    </dict>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>2.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>7</integer>
    </array>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>UIFileSharingEnabled</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
</dict>
</plist>
EOF

mkdir -p "$RESOURCES_DIR/../visionos-res"
echo "✓ Created Info.plist"

# Summary
echo ""
echo "=============================================="
echo "Assets Prepared!"
echo "=============================================="
echo ""
echo "Resources directory: $RESOURCES_DIR"
echo ""
ls -la "$RESOURCES_DIR"
if [ -d "$RESOURCES_DIR/rct2" ]; then
    echo ""
    echo "RCT2 base game files:"
    ls -la "$RESOURCES_DIR/rct2/Data/" 2>/dev/null || true
fi
echo ""
echo "Next steps:"
echo "  1. Ensure the visionos-resources folder exists in the repo (this script creates it)"
echo "  2. Build in Xcode (resources are copied into the app bundle root at build time)"
echo "  3. Run on visionOS Simulator"
echo ""
