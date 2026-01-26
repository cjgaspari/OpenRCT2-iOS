# OpenRCT2 macOS CMake Build Guide

## Base Guide (Provided Instructions)

### Prerequisites
- RCT2 game files available on disk.
- OS X Developer Tools.
- Homebrew (or MacPorts / Fink).
- Xcode (optional).

### Install Libraries (Homebrew Example)
```sh
brew install cmake duktape freetype icu4c libpng libzip nlohmann-json openssl pkg-config sdl2 speexdsp
```

### Build OpenRCT2
```sh
cd /path/to/repo/OpenRCT2
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./install
make -j$(sysctl -n hw.logicalcpu) install
```

### Run
```sh
ln -s ./install/share/openrct2 data
./openrct2
```

Notes:
- The game prompts for the RCT2 installation path on first launch and builds object indices.
- After first install, rebuilding does not require install:
  ```sh
  make -j$(sysctl -n hw.logicalcpu)
  ```

### Troubleshooting (Provided Instructions)

Problem 1: When running cmake, I get the error `-- No package 'openssl' found`
- Try both solutions in Problem 2.

Problem 2: When running cmake or make, I get some other weird error involving openssl
- Solution 1: Verify universal build of openssl
  ```sh
  file /usr/local/Cellar/openssl/1.0.2h_1/lib/libcrypto.1.0.0.dylib
  ```
  If only i386 or x86_64 are listed, run:
  ```sh
  brew reinstall openssl --universal
  ```
- Solution 2: Ensure build uses Homebrew openssl
  ```sh
  brew link --force openssl
  ```
  To undo later:
  ```sh
  brew unlink openssl
  ```

Problem 3: When running cmake, I get the error `-- No package 'gl' found`
- Create `gl.pc`:
  ```sh
  cd ..
  mkdir pkgconfig
  cd pkgconfig
  ```
  Create `gl.pc` with:
  ```
  PACKAGE=GL
  Name: OpenGL
  Description: OpenGL
  Version: 11.1.1
  Cflags: -framework OpenGL -framework AGL
  Libs: -Wl,-framework,OpenGL,-framework,AGL
  ```
- Export pkg-config path and return to build:
  ```sh
  export PKG_CONFIG_PATH=$(pwd):$PKG_CONFIG_PATH
  cd ../build
  ```

Problem 4: When running cmake, I get the error `ld: library not found for -lSDL2`
- Fix permissions and relink:
  ```sh
  sudo chown root:wheel /usr/local/bin/brew
  sudo brew link sdl2
  ```
- If `/usr/local/lib` is missing from `LIBRARY_PATH`, add to `~/.bash_profile`:
  ```sh
  export LIBRARY_PATH="$LIBRARY_PATH:/usr/local/lib"
  ```

Problem 5: cmake cannot find the required ICU library
- Workaround:
  ```sh
  export CMAKE_PREFIX_PATH=/usr/local/opt/icu4c
  cmake ..
  ```

## Addendum: Issue Resolution Steps (Successful Only)
This section is updated only with successful steps taken beyond the base guide.

- Updated `fixup_bundle` to search the OpenRCT2 macOS dependency dylib directory so `@rpath` libraries resolve during install (`src/openrct2-ui/CMakeLists.txt`).
- Reconfigured and rebuilt the install target:
  ```sh
  cmake .. -DCMAKE_INSTALL_PREFIX=./install
  make -j$(sysctl -n hw.logicalcpu) install
  ```
- Launched the app bundle to verify it runs:
  ```sh
  open /Users/cjgaspari/Developer/OpenRCT2-iOS/build/OpenRCT2.app
  ```
