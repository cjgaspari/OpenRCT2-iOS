# OpenRCT2 iOS Target - Developer Setup Guide

This guide walks you through building and running OpenRCT2 on the iOS Simulator from a fresh development environment.

## Prerequisites

- **macOS** (tested on macOS 15+)
- **Xcode** (with iOS SDK 18+, command line tools installed)
- **CMake** 3.20+ (`brew install cmake`)
- **Ninja** (optional, `brew install ninja`)
- **vcpkg** for iOS dependencies

Verify Xcode is set up:
```bash
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer

xcrun --sdk iphonesimulator --show-sdk-path
# Should show path to iOS Simulator SDK
```

---

## Quick Start (Automated Setup)

If you want to get up and running quickly, use the provided setup scripts:

```bash
# 1. Clone and enter the repository
git clone https://github.com/OpenRCT2/OpenRCT2.git OpenRCT2-iOS
cd OpenRCT2-iOS
git checkout develop  # or your iOS branch

# 2. Install all iOS dependencies (vcpkg, SDL2, ICU)
./setup-ios-deps.sh

# 3. Configure and build
./cmake-ios.sh
cd build-ios && cmake --build . -j$(sysctl -n hw.ncpu)

# 4. Create app bundle (auto-detects local OpenRCT2.app or downloads data)
./prepare-ios-app.sh

# 5. Run on simulator
xcrun simctl boot "iPhone Air"
xcrun simctl install booted build-ios/openrct2.app
xcrun simctl launch booted io.openrct2.OpenRCT2
```

The rest of this guide explains each step in detail for troubleshooting or manual setup.

---

## Directory Structure

After setup, your workspace will look like:
```
OpenRCT2-iOS/
├── src/                    # OpenRCT2 source code
├── cmake/                  # CMake modules (including ios-simulator.toolchain.cmake)
├── ios-res/                # iOS resources (Info.plist)
├── build-ios/              # Build output directory
├── ios-deps/               # SDL2 framework and ICU
│   ├── SDL2.framework/
│   └── icu-ios/
├── ios-vcpkg/              # vcpkg with iOS dependencies
├── setup-ios-deps.sh       # ⭐ Installs all dependencies (vcpkg, SDL2, ICU)
├── cmake-ios.sh            # CMake configuration script
├── prepare-ios-app.sh      # ⭐ Creates iOS app bundle with data files
└── build-ios.sh            # Alternative build script
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/OpenRCT2/OpenRCT2.git OpenRCT2-iOS
cd OpenRCT2-iOS
git checkout develop  # or your iOS branch
```

---

## Step 2: Build iOS Dependencies

> **💡 Automated alternative:** Run `./setup-ios-deps.sh` to install all dependencies automatically.
> Use `--skip-vcpkg`, `--skip-sdl2`, or `--skip-icu` to skip specific components.

### 2.1 Set Up vcpkg for iOS Simulator

```bash
# Clone vcpkg
git clone https://github.com/microsoft/vcpkg.git ios-vcpkg
cd ios-vcpkg
./bootstrap-vcpkg.sh

# Install dependencies for iOS Simulator (arm64)
./vcpkg install zlib:arm64-ios-simulator
./vcpkg install zstd:arm64-ios-simulator
./vcpkg install libpng:arm64-ios-simulator
./vcpkg install freetype:arm64-ios-simulator
./vcpkg install speexdsp:arm64-ios-simulator
./vcpkg install libzip:arm64-ios-simulator
./vcpkg install openssl:arm64-ios-simulator
./vcpkg install bzip2:arm64-ios-simulator
./vcpkg install brotli:arm64-ios-simulator
./vcpkg install nlohmann-json:arm64-ios-simulator

cd ..
```

### 2.2 Build SDL2 for iOS Simulator

```bash
mkdir -p ios-deps && cd ios-deps

# Download SDL2 source
curl -L https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9.tar.gz | tar xz
cd SDL2-2.30.9/Xcode/SDL

# Build for iOS Simulator
xcodebuild -project SDL.xcodeproj \
    -scheme "Framework-iOS" \
    -configuration Release \
    -sdk iphonesimulator \
    -derivedDataPath ./build \
    ONLY_ACTIVE_ARCH=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# Copy the framework
cp -R ./build/Build/Products/Release-iphonesimulator/SDL2.framework ../../

cd ../../..
```

### 2.3 Build ICU for iOS Simulator

ICU requires a two-stage build (host tools first, then cross-compile):

```bash
cd ios-deps

# Download ICU 76
curl -L https://github.com/unicode-org/icu/releases/download/release-76-1/icu4c-76_1-src.tgz | tar xz

# Stage 1: Build host tools (macOS)
cd icu/source
mkdir build-host && cd build-host
../configure --disable-samples --disable-tests
make -j$(sysctl -n hw.ncpu)
cd ..

# Stage 2: Cross-compile for iOS Simulator
mkdir build-ios && cd build-ios

export SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
export MIN_IOS=15.0

# Note: --disable-tools is critical - ICU tools use system() which is unavailable on iOS
../configure \
    --host=arm-apple-darwin \
    --with-cross-build=$(pwd)/../build-host \
    --enable-static \
    --disable-shared \
    --disable-samples \
    --disable-tests \
    --disable-tools \
    --disable-extras \
    --prefix=$(pwd)/../../icu-ios \
    CC="clang -arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS" \
    CXX="clang++ -arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS -std=c++17 -stdlib=libc++" \
    CFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS" \
    CXXFLAGS="-arch arm64 -isysroot $SDK_PATH -mios-simulator-version-min=$MIN_IOS -std=c++17 -stdlib=libc++"

make -j$(sysctl -n hw.ncpu)
make install

cd ../../..
```

---

## Step 3: Configure CMake for iOS

Run the CMake configuration script:

```bash
./cmake-ios.sh
```

Or manually:

```bash
WORKSPACE="$(pwd)"
BUILD_DIR="$WORKSPACE/build-ios"
VCPKG_ROOT="$WORKSPACE/ios-vcpkg/installed/arm64-ios-simulator"
ICU_ROOT="$WORKSPACE/ios-deps/icu-ios"
SDL2_FRAMEWORK="$WORKSPACE/ios-deps/SDL2.framework"

mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

export PKG_CONFIG=/bin/false  # Prevent picking up macOS libraries

cmake "$WORKSPACE" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_PREFIX_PATH="$VCPKG_ROOT;$ICU_ROOT" \
    -DCMAKE_FIND_ROOT_PATH="$VCPKG_ROOT;$ICU_ROOT" \
    -DSDL2_FRAMEWORK_PATH="$SDL2_FRAMEWORK" \
    -DSPEEXDSP_ROOT="$VCPKG_ROOT" \
    -DFREETYPE_LIBRARY="$VCPKG_ROOT/lib/libfreetype.a" \
    -DFREETYPE_INCLUDE_DIRS="$VCPKG_ROOT/include" \
    -DZLIB_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DZLIB_LIBRARY="$VCPKG_ROOT/lib/libz.a" \
    -DPNG_PNG_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DPNG_LIBRARY="$VCPKG_ROOT/lib/libpng16.a" \
    -DICU_ROOT="$ICU_ROOT" \
    -DICU_INCLUDE_DIR="$ICU_ROOT/include" \
    -DICU_UC_LIBRARY="$ICU_ROOT/lib/libicuuc.a" \
    -DICU_I18N_LIBRARY="$ICU_ROOT/lib/libicui18n.a" \
    -DICU_DATA_LIBRARY="$ICU_ROOT/lib/libicudata.a" \
    -DLIBZIP_LIBRARY="$VCPKG_ROOT/lib/libzip.a" \
    -DLIBZIP_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DOPENSSL_CRYPTO_LIBRARY="$VCPKG_ROOT/lib/libcrypto.a" \
    -DBZIP2_LIBRARY="$VCPKG_ROOT/lib/libbz2.a" \
    -DBROTLI_DEC_LIBRARY="$VCPKG_ROOT/lib/libbrotlidec.a" \
    -DBROTLI_COMMON_LIBRARY="$VCPKG_ROOT/lib/libbrotlicommon.a" \
    -DZSTD_LIBRARY="$VCPKG_ROOT/lib/libzstd.a" \
    -DZSTD_INCLUDE_DIR="$VCPKG_ROOT/include" \
    -DDISABLE_DISCORD_RPC=ON \
    -DDISABLE_OPENGL=ON \
    -DDISABLE_HTTP=ON \
    -DDISABLE_NETWORK=ON \
    -DDISABLE_FLAC=ON \
    -DDISABLE_VORBIS=ON \
    -DENABLE_SCRIPTING=OFF \
    -DMACOS_USE_DEPENDENCIES=OFF \
    -DCMAKE_BUILD_TYPE=Release
```

---

## Step 4: Build OpenRCT2

```bash
cd build-ios
cmake --build . -j$(sysctl -n hw.ncpu)
```

This produces the `openrct2` executable in `build-ios/`.

---

## Step 5: Create iOS App Bundle

> **💡 Automated alternative:** Run `./prepare-ios-app.sh` to create the app bundle automatically.
> It checks for `/Applications/OpenRCT2.app` first, or downloads data from GitHub.
> Use `--download-data` to force download, or `--skip-data` to skip data files.

```bash
cd build-ios

# Create app bundle structure
mkdir -p openrct2.app/Frameworks

# Copy executable
cp openrct2 openrct2.app/

# Copy Info.plist
cp ../ios-res/Info.plist openrct2.app/

# Copy SDL2 framework
cp -R ../ios-deps/SDL2.framework openrct2.app/Frameworks/

# Copy data files from source
cp -R ../data/language openrct2.app/
cp -R ../data/shaders openrct2.app/
cp -R ../data/scenario_patches openrct2.app/
```

### 5.1 Copy OpenRCT2 Data Files

OpenRCT2 requires data files (g2.dat, objects, sequences). Check if you have OpenRCT2 installed locally first:

```bash
# Option A: Copy from local installation (preferred)
if [ -d "/Applications/OpenRCT2.app" ]; then
    RESOURCES="/Applications/OpenRCT2.app/Contents/Resources"
    cp "$RESOURCES/g2.dat" openrct2.app/
    cp -R "$RESOURCES/object" openrct2.app/
    cp -R "$RESOURCES/sequence" openrct2.app/
    cp -R "$RESOURCES/assetpack" openrct2.app/
    cp "$RESOURCES/fonts.dat" openrct2.app/
    echo "✓ Copied data files from /Applications/OpenRCT2.app"
fi
```

If OpenRCT2 is not installed locally, download from the official release:

```bash
# Option B: Download from GitHub release
curl -L -o OpenRCT2-macos.zip \
    https://github.com/OpenRCT2/OpenRCT2/releases/download/v0.4.30/OpenRCT2-v0.4.30-macos-universal.zip

unzip -o OpenRCT2-macos.zip -d extract_temp

# Copy required data files to app bundle root (not in data/ subdirectory)
cp extract_temp/OpenRCT2.app/Contents/Resources/g2.dat openrct2.app/
cp -R extract_temp/OpenRCT2.app/Contents/Resources/object openrct2.app/
cp -R extract_temp/OpenRCT2.app/Contents/Resources/sequence openrct2.app/
cp -R extract_temp/OpenRCT2.app/Contents/Resources/assetpack openrct2.app/
cp extract_temp/OpenRCT2.app/Contents/Resources/fonts.dat openrct2.app/

# Clean up
rm -rf extract_temp OpenRCT2-macos.zip
```

### 5.2 Sign the App Bundle

```bash
codesign --force --sign - --deep openrct2.app
```

---

## Step 6: Run on iPhone Air Simulator

### 6.1 List Available Simulators

```bash
xcrun simctl list devices available | grep -i "iphone"
```

Find "iPhone Air" in the list and note its UUID.

### 6.2 Boot the Simulator

```bash
# Boot iPhone Air (replace UUID with actual value from list)
xcrun simctl boot "iPhone Air"

# Or boot by UUID
xcrun simctl boot 4E88C2A3-F9B6-46BD-B755-AAD4906F0C13

# Open Simulator app
open -a Simulator
```

### 6.3 Install and Launch

```bash
# Install the app
xcrun simctl install booted build-ios/openrct2.app

# Launch the app
xcrun simctl launch booted io.openrct2.OpenRCT2
```

### 6.4 View Logs (Optional)

```bash
# Stream logs from the app
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "openrct2"' --style compact
```

---

## Quick Reference Commands

```bash
# Rebuild after code changes
cd build-ios && cmake --build . -j$(sysctl -n hw.ncpu)

# Update app and relaunch
cp openrct2 openrct2.app/ && \
codesign --force --sign - --deep openrct2.app && \
xcrun simctl install booted openrct2.app && \
xcrun simctl launch booted io.openrct2.OpenRCT2

# Take a screenshot
xcrun simctl io booted screenshot ~/Desktop/openrct2_screenshot.png

# Shutdown simulator
xcrun simctl shutdown booted
```

---

## Troubleshooting

### "No devices are booted"
Boot a simulator first: `xcrun simctl boot "iPhone Air"`

### App crashes immediately
Check crash logs:
```bash
ls -la ~/Library/Logs/DiagnosticReports/ | grep openrct
cat ~/Library/Logs/DiagnosticReports/openrct2-*.ips | head -100
```

### SDL2.framework not found at runtime
Ensure the framework is in `openrct2.app/Frameworks/` and the app is re-signed after copying.

### Language files not found
iOS app bundles have a flat structure. Data files must be at the app bundle root, not in a `data/` subdirectory.

### RCT2 game data required
OpenRCT2 needs the original RollerCoaster Tycoon 2 game files to fully run. You can configure the path in the app or place files in the simulator's Documents directory.

---

## Clean Build / Start Fresh

If you need to start over or clean up build artifacts:

### Clean Build Only (Keep Dependencies)

```bash
# Remove just the build directory
rm -rf build-ios

# Then re-run cmake configuration and build
./cmake-ios.sh
cd build-ios && cmake --build . -j$(sysctl -n hw.ncpu)
```

### Full Clean (Remove Everything)

```bash
# Remove all build artifacts and dependencies
rm -rf build-ios
rm -rf ios-deps
rm -rf ios-vcpkg

# Remove app from simulator
xcrun simctl uninstall booted io.openrct2.OpenRCT2

# Then follow the setup guide from Step 2
```

### Clean Specific Components

```bash
# Clean only vcpkg (re-download/rebuild all vcpkg packages)
rm -rf ios-vcpkg

# Clean only ICU (rebuild ICU from scratch)
rm -rf ios-deps/icu ios-deps/icu-ios

# Clean only SDL2 (rebuild SDL2 framework)
rm -rf ios-deps/SDL2-* ios-deps/SDL2.framework

# Clean only the app bundle (keeps compiled binary)
rm -rf build-ios/openrct2.app
```

### Reset Simulator

```bash
# Erase all content and settings from simulator
xcrun simctl erase booted

# Or erase a specific simulator by name
xcrun simctl erase "iPhone Air"

# Delete and recreate simulator (nuclear option)
xcrun simctl delete "iPhone Air"
xcrun simctl create "iPhone Air" "com.apple.CoreSimulator.SimDeviceType.iPhone-Air"
```

---

## Architecture Notes

- **SDL2**: Provides the rendering backend and iOS lifecycle integration via `SDL_UIKitRunApp`
- **Entry Point**: `src/openrct2-ui/main_ios.mm` handles iOS-specific initialization
- **Platform Code**: `src/openrct2/platform/Platform.macOS.mm` is shared between macOS and iOS with `TARGET_OS_IPHONE` guards
- **No OpenGL**: iOS build uses software rendering (OpenGL is disabled)
- **No Network**: HTTP and multiplayer are disabled for the iOS target
