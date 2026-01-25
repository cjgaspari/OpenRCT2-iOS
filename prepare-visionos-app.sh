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

# Check for local OpenRCT2 installation first
if [ "$FORCE_DOWNLOAD" = false ] && [ -d "/Applications/OpenRCT2.app/Contents/Resources" ]; then
    DATA_SOURCE="/Applications/OpenRCT2.app/Contents/Resources"
    echo "Found local OpenRCT2 installation at $DATA_SOURCE"
fi

# Download from GitHub if no local install
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

# Copy data files
if [ -d "$DATA_SOURCE" ]; then
    # g2.dat - OpenRCT2 graphics (required)
    if [ -f "$DATA_SOURCE/g2.dat" ]; then
        cp "$DATA_SOURCE/g2.dat" "$RESOURCES_DIR/"
        echo "✓ Copied g2.dat"
    else
        echo "⚠ g2.dat not found!"
    fi
    
    # Optional files
    [ -f "$DATA_SOURCE/fonts.dat" ] && cp "$DATA_SOURCE/fonts.dat" "$RESOURCES_DIR/" && echo "✓ Copied fonts.dat"
    [ -d "$DATA_SOURCE/object" ] && cp -R "$DATA_SOURCE/object" "$RESOURCES_DIR/" && echo "✓ Copied objects"
    [ -d "$DATA_SOURCE/sequence" ] && cp -R "$DATA_SOURCE/sequence" "$RESOURCES_DIR/" && echo "✓ Copied sequences"
    [ -d "$DATA_SOURCE/assetpack" ] && cp -R "$DATA_SOURCE/assetpack" "$RESOURCES_DIR/" && echo "✓ Copied assetpacks"
else
    echo "⚠ Could not find data source"
fi

# Clean up temp directory
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    echo "✓ Cleaned up temporary files"
fi

# Create Info.plist for visionOS
echo ""
echo "=== Creating visionOS Info.plist ==="

cat > "$RESOURCES_DIR/../visionos-res/Info.plist" << 'EOF'
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
echo ""
echo "Next steps:"
echo "  1. In Xcode, add the visionos-resources folder to your project"
echo "  2. Ensure files are added to 'Copy Bundle Resources' build phase"
echo "  3. Build and run on visionOS Simulator"
echo ""
echo "Note: Users must provide RCT2 base game files (g1.dat) in:"
echo "  Documents/OpenRCT2/rct2/Data/"
echo ""
echo "They can copy files to the app via Files.app on visionOS."
echo ""
