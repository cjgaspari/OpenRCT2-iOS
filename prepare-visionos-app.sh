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

# Find and copy RCT2 base game files (g1.dat, etc.)
echo ""
echo "=== Looking for RCT2 Base Game Files ==="

RCT2_SOURCE=""

# Common locations for RCT2 game files
RCT2_SEARCH_PATHS=(
    "$HOME/RCT Game Files/RCT2/Data"
    "/Applications/RCT Game Files/RCT2/Data"
    "$HOME/Library/Application Support/OpenRCT2/rct2/Data"
    "$HOME/GOG Games/RollerCoaster Tycoon 2 Triple Thrill Pack/Data"
    "$HOME/Library/Application Support/Steam/steamapps/common/Rollercoaster Tycoon 2 Triple Thrill Pack/Data"
    "/Applications/RollerCoaster Tycoon 2.app/Contents/Resources/Data"
)

for path in "${RCT2_SEARCH_PATHS[@]}"; do
    if [ -f "$path/g1.dat" ]; then
        RCT2_SOURCE="$path"
        echo "Found RCT2 game files at: $RCT2_SOURCE"
        break
    fi
done

if [ -n "$RCT2_SOURCE" ]; then
    # Create rct2 folder in resources
    mkdir -p "$RESOURCES_DIR/rct2/Data"
    
    # Copy essential RCT2 files
    for f in g1.dat CSS1.DAT CSS2.DAT CSS4.DAT CSS5.DAT CSS6.DAT CSS7.DAT CSS8.DAT CSS9.DAT; do
        if [ -f "$RCT2_SOURCE/$f" ]; then
            cp "$RCT2_SOURCE/$f" "$RESOURCES_DIR/rct2/Data/"
            echo "✓ Copied $f"
        elif [ -f "$RCT2_SOURCE/$(echo $f | tr '[:upper:]' '[:lower:]')" ]; then
            # Try lowercase version
            cp "$RCT2_SOURCE/$(echo $f | tr '[:upper:]' '[:lower:]')" "$RESOURCES_DIR/rct2/Data/$f"
            echo "✓ Copied $f"
        fi
    done
    
    # Copy ObjData folder if it exists
    if [ -d "$RCT2_SOURCE/../ObjData" ]; then
        cp -R "$RCT2_SOURCE/../ObjData" "$RESOURCES_DIR/rct2/"
        echo "✓ Copied ObjData"
    fi
    
    # Copy Scenarios if they exist
    if [ -d "$RCT2_SOURCE/../Scenarios" ]; then
        cp -R "$RCT2_SOURCE/../Scenarios" "$RESOURCES_DIR/rct2/"
        echo "✓ Copied Scenarios"
    fi
    
    # Copy Tracks if they exist
    if [ -d "$RCT2_SOURCE/../Tracks" ]; then
        cp -R "$RCT2_SOURCE/../Tracks" "$RESOURCES_DIR/rct2/"
        echo "✓ Copied Tracks"
    fi
else
    echo "⚠ RCT2 base game files not found!"
    echo "  Searched locations:"
    for path in "${RCT2_SEARCH_PATHS[@]}"; do
        echo "    - $path"
    done
    echo ""
    echo "  You can set RCT2_PATH environment variable to specify location:"
    echo "    RCT2_PATH=/path/to/rct2/Data ./prepare-visionos-app.sh"
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
echo "  1. In Xcode, add the visionos-resources folder to your project"
echo "  2. Ensure files are added to 'Copy Bundle Resources' build phase"
echo "  3. Build and run on visionOS Simulator"
echo ""
