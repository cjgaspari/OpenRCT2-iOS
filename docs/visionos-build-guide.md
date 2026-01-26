# OpenRCT2 visionOS Build Guide

## Base Guide (CMake-First, Xcode Run)

### Prerequisites
- Xcode with visionOS platform installed (simulator runtime recommended).
- CMake installed.
- visionOS dependencies available (ICU, libzip, and other libs for visionOS).

### Build libopenrct2.a for visionOS Simulator (CMake)
```sh
cmake -S . -B build-visionos \
  -DCMAKE_TOOLCHAIN_FILE=cmake/visionos-simulator.toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DDISABLE_GUI=OFF \
  -DDISABLE_SDL=ON \
  -DDISABLE_DISCORD_RPC=ON \
  -DDISABLE_OPENGL=ON \
  -DDISABLE_HTTP=ON \
  -DDISABLE_NETWORK=ON \
  -DDISABLE_FLAC=ON \
  -DDISABLE_VORBIS=ON \
  -DENABLE_SCRIPTING=OFF \
  -DMACOS_USE_DEPENDENCIES=OFF \
  -DDOWNLOAD_TITLE_SEQUENCES=OFF \
  -DDOWNLOAD_OBJECTS=OFF \
  -DDOWNLOAD_OPENSFX=OFF \
  -DDOWNLOAD_OPENMSX=OFF

cmake --build build-visionos --target libopenrct2 -j$(sysctl -n hw.ncpu)
```

### Prepare visionOS Resources
```sh
./build-vision-graphics.sh
./prepare-visionos-app.sh
```

### Build and Run with Xcode (visionOS Simulator)
```sh
xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 \
  -destination 'platform=visionOS Simulator,name=Apple Vision Pro' \
  build
```

Then run the app on the simulator (via Xcode or `xcrun simctl`).

## Addendum: Issue Resolution Steps (Successful Only)
This section is updated only with successful steps taken beyond the base guide.

### vcpkg + visionOS deps (simulator)
```sh
git clone https://github.com/microsoft/vcpkg ios-vcpkg
./ios-vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

Updated triplets:
- `vcpkg/triplets/community/arm64-xros-simulator.cmake`
- `vcpkg/triplets/community/arm64-xros.cmake`

Changes applied:
- `VCPKG_CMAKE_SYSTEM_NAME` set to `Darwin`.
- `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` set to the visionOS toolchain files.
- `VCPKG_C_FLAGS`/`VCPKG_CXX_FLAGS` set to `-fPIC` (simulator also uses `-Qunused-arguments`).

```sh
./ios-vcpkg/vcpkg install zlib zstd libpng freetype bzip2 brotli nlohmann-json \
  --triplet arm64-xros-simulator \
  --overlay-triplets=vcpkg/triplets/community \
  --recurse
```

### Build visionOS libs/resources (simulator)
```sh
./build-icu-visionos.sh --simulator
./build-libzip-visionos.sh --simulator
./build-visionos.sh --simulator
./build-vision-graphics.sh
./prepare-visionos-app.sh
```

### Build, install, launch (visionOS Simulator)
```sh
xcrun simctl boot 9EC16DBE-2A87-4655-B4BE-966355FDE0DC

xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 \
  -destination 'platform=visionOS Simulator,id=9EC16DBE-2A87-4655-B4BE-966355FDE0DC' \
  -configuration Debug \
  build

xcrun simctl install 9EC16DBE-2A87-4655-B4BE-966355FDE0DC \
  /Users/cjgaspari/Library/Developer/Xcode/DerivedData/OpenRCT2-avzzmbdocphjaeahkchvjqlqakdd/Build/Products/Debug-xrsimulator/OpenRCT2.app

xcrun simctl launch 9EC16DBE-2A87-4655-B4BE-966355FDE0DC com.openrct2.visionos
```

### Issue: g2.dat invalid entry (use macOS build/ dat files)
```sh
cp -f build/g2.dat build/fonts.dat build/tracks.dat visionos-resources/

xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 \
  -destination 'platform=visionOS Simulator,id=9EC16DBE-2A87-4655-B4BE-966355FDE0DC' \
  -configuration Debug \
  build

xcrun simctl install 9EC16DBE-2A87-4655-B4BE-966355FDE0DC \
  /Users/cjgaspari/Library/Developer/Xcode/DerivedData/OpenRCT2-avzzmbdocphjaeahkchvjqlqakdd/Build/Products/Debug-xrsimulator/OpenRCT2.app

xcrun simctl launch 9EC16DBE-2A87-4655-B4BE-966355FDE0DC com.openrct2.visionos
```

### Verify rebuild (temporary build marker)
Added a temporary log line in `Sources/OpenRCT2Core/visionos/VisionOSUiContext.cpp`:
```
[OpenRCT2] visionOS build marker: VOS-G2FIX-2026-01-26-01
```

Rebuild + launch to confirm the marker prints:
```sh
xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 \
  -destination 'platform=visionOS Simulator,id=9EC16DBE-2A87-4655-B4BE-966355FDE0DC' \
  -configuration Debug \
  build

xcrun simctl install 9EC16DBE-2A87-4655-B4BE-966355FDE0DC \
  /Users/cjgaspari/Library/Developer/Xcode/DerivedData/OpenRCT2-avzzmbdocphjaeahkchvjqlqakdd/Build/Products/Debug-xrsimulator/OpenRCT2.app

xcrun simctl launch --console 9EC16DBE-2A87-4655-B4BE-966355FDE0DC com.openrct2.visionos
```

### Normalize visionOS logging (os_log only)
Swapped visionOS `printf`/`fprintf` logs to `os_log` for consistent visibility, and removed duplicate logs.

Rebuild and view logs via:
```sh
xcodebuild -project OpenRCT2.xcodeproj -scheme OpenRCT2 \
  -destination 'platform=visionOS Simulator,id=9EC16DBE-2A87-4655-B4BE-966355FDE0DC' \
  -configuration Debug \
  build

xcrun simctl spawn 9EC16DBE-2A87-4655-B4BE-966355FDE0DC log stream \
  --predicate 'process == "OpenRCT2"'
```
