#!/bin/bash
# build-visionos.sh - Build OpenRCT2 for visionOS (simulator or device)
#
# This script builds the full libopenrct2.a static library for visionOS.
# After building, the library can be linked into the Xcode project.
#
# Usage: ./build-visionos.sh [--simulator|--device] [--skip-deps] [--clean] [--install-deps] [--build-icu] [--build-libzip] [--boot-sim]
#
# Prerequisites:
#   - Xcode with visionOS SDK (simulator runtime optional for device-only builds)
#   - vcpkg dependencies (run with --install-deps first time)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$SCRIPT_DIR"
VCPKG_ROOT="$WORKSPACE/ios-vcpkg"

# Parse arguments
BUILD_TARGET="simulator"
if [[ "${DEVICE:-}" == "1" ]]; then
    BUILD_TARGET="device"
fi
if [[ "${SIMULATOR:-}" == "1" ]]; then
    BUILD_TARGET="simulator"
fi

SKIP_DEPS=false
CLEAN_BUILD=false
INSTALL_DEPS=false
BUILD_ICU=false
BUILD_LIBZIP=false
BOOT_SIM=false

for arg in "$@"; do
    case $arg in
        --device) BUILD_TARGET="device" ;;
        --simulator) BUILD_TARGET="simulator" ;;
        --skip-deps) SKIP_DEPS=true ;;
        --clean) CLEAN_BUILD=true ;;
        --install-deps) INSTALL_DEPS=true ;;
        --build-icu) BUILD_ICU=true ;;
        --build-libzip) BUILD_LIBZIP=true ;;
        --boot-sim) BOOT_SIM=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --simulator     Build for visionOS Simulator (default)"
            echo "  --device        Build for visionOS device"
            echo "  --skip-deps     Skip vcpkg dependency check"
            echo "  --install-deps  Install vcpkg dependencies (first time setup)"
            echo "  --build-icu     Build ICU for the selected platform"
            echo "  --build-libzip  Build libzip for the selected platform"
            echo "  --clean         Clean build directory before building"
            echo "  --boot-sim      Boot the selected visionOS simulator (optional)"
            exit 0
            ;;
    esac
done

if [[ "$INSTALL_DEPS" == "true" ]]; then
    BUILD_ICU=true
    BUILD_LIBZIP=true
fi

if [[ "$BUILD_TARGET" == "device" ]] && [[ "$BOOT_SIM" == "true" ]]; then
    echo "⚠ --boot-sim ignored for device builds"
    BOOT_SIM=false
fi

if [[ "$BUILD_TARGET" == "device" ]]; then
    BUILD_DIR="$WORKSPACE/build-visionos-device"
    TRIPLET="arm64-xros"
    TOOLCHAIN_FILE="$WORKSPACE/cmake/visionos-arm64.toolchain.cmake"
    VCPKG_INSTALLED="$VCPKG_ROOT/installed/$TRIPLET"
    ICU_ROOT="$WORKSPACE/visionos-deps/icu-visionos-device"
    LIBZIP_ROOT="$WORKSPACE/visionos-deps/libzip-visionos-device"
    SDK_NAME="xros"
    SDK_LABEL="visionOS Device"
else
    BUILD_DIR="$WORKSPACE/build-visionos"
    TRIPLET="arm64-xros-simulator"
    TOOLCHAIN_FILE="$WORKSPACE/cmake/visionos-simulator.toolchain.cmake"
    VCPKG_INSTALLED="$VCPKG_ROOT/installed/$TRIPLET"
    ICU_ROOT="$WORKSPACE/visionos-deps/icu-visionos"
    LIBZIP_ROOT="$WORKSPACE/visionos-deps/libzip-visionos"
    SDK_NAME="xrsimulator"
    SDK_LABEL="visionOS Simulator"
fi

echo "=============================================="
echo "Building OpenRCT2 for ${SDK_LABEL}"
echo "=============================================="
echo ""

# ------------------------------
# Xcode + visionOS SDK check
# ------------------------------
if [[ "$BUILD_TARGET" == "simulator" ]]; then
    # Discover the correct visionOS Simulator SDK name from Xcode (e.g. xrsimulator26.1)
    VISIONOS_SIM_SDK="$(xcodebuild -showsdks | awk '/Simulator - visionOS/{print $NF; exit}')"

    if [[ -z "${VISIONOS_SIM_SDK}" ]]; then
        echo "❌ visionOS Simulator SDK not found!"
        echo "   Install visionOS platform in Xcode (Xcode > Settings > Platforms)"
        echo "   Debug: xcodebuild -showsdks"
        exit 1
    fi

    if ! xcrun --sdk "${VISIONOS_SIM_SDK}" --show-sdk-path &>/dev/null; then
        echo "❌ visionOS Simulator SDK not usable via xcrun: ${VISIONOS_SIM_SDK}"
        echo "   Debug: xcodebuild -showsdks"
        exit 1
    fi

    XROS_SDK="$(xcrun --sdk "${VISIONOS_SIM_SDK}" --show-sdk-path)"
    echo "✓ visionOS Simulator SDK (${VISIONOS_SIM_SDK}): $XROS_SDK"
else
    if ! xcrun --sdk xros --show-sdk-path &>/dev/null; then
        echo "❌ visionOS device SDK not usable via xcrun: xros"
        echo "   Install visionOS platform in Xcode (Xcode > Settings > Platforms)"
        exit 1
    fi

    XROS_SDK="$(xcrun --sdk xros --show-sdk-path)"
    echo "✓ visionOS Device SDK (xros): $XROS_SDK"
fi

# ------------------------------
# Simulator device selection
# (This build is a static library, but we still validate that a usable
#  visionOS simulator runtime + device type profiles exist, and we select
#  a device UDID for downstream steps / sanity checks.)
# ------------------------------
if [[ "$BUILD_TARGET" == "simulator" ]]; then

# Check for Vision Pro device types - use explicit matching
# Also check the device type identifier pattern for visionOS
VISION_DEVICETYPES="$(xcrun simctl list devicetypes 2>/dev/null | grep -iE 'vision|Apple-Vision' || true)"
if [[ -z "${VISION_DEVICETYPES}" ]]; then
    echo "⚠ visionOS device types not found (Vision Pro profile may be missing)."
    echo "  This is OK for building the library - the SDK is sufficient."
    echo "  To run on simulator later, install device profiles:"
    echo "    Xcode > Settings > Platforms > visionOS (install/reinstall)"
    echo ""
    # Set flag to skip simulator device selection
    SKIP_SIMULATOR_DEVICE=true
else
    echo "✓ Found visionOS device types"
    SKIP_SIMULATOR_DEVICE=false
fi

SIMCTL_JSON="$(xcrun simctl list --json 2>/dev/null || true)"
if [[ -z "${SIMCTL_JSON}" ]]; then
    echo "⚠ Failed to read simulator list (xcrun simctl list --json)."
    SKIP_SIMULATOR_DEVICE=true
fi

# Skip device selection if device types are not available
if [[ "${SKIP_SIMULATOR_DEVICE:-false}" == "true" ]]; then
    echo "⚠ Skipping simulator device selection (not needed for library build)"
    XROS_RUNTIME_ID=""
    VISIONOS_SIM_UDID=""
else

# Pick newest AVAILABLE xrOS runtime and a usable Vision Pro device in it.
# If no device exists, create one.
read -r XROS_RUNTIME_ID VISIONOS_SIM_UDID < <(python3 - <<'PY'
import json, re, sys, subprocess

data = json.loads(sys.stdin.read())

# Runtime availability helper

def runtime_is_available(r):
    if r.get("isAvailable") is True:
        return True
    avail = (r.get("availability") or "").lower()
    return ("available" in avail) and ("unavailable" not in avail)

# Parse versions like "26.1" or "1.2"

def vtuple(v):
    nums = [int(x) for x in re.findall(r"\d+", v or "0")]
    return tuple(nums + [0] * (3 - len(nums)))

# Choose xrOS runtime (visionOS)
runtimes = [r for r in data.get("runtimes", []) if "xrOS" in (r.get("identifier") or "")]
runtimes = [r for r in runtimes if runtime_is_available(r)]
runtimes.sort(key=lambda r: vtuple(r.get("version") or r.get("runtimeVersion") or "0"), reverse=True)

runtime_id = runtimes[0]["identifier"] if runtimes else ""

udid = ""
if runtime_id:
    devices_by_runtime = (data.get("devices") or {})
    devs = devices_by_runtime.get(runtime_id, [])

    def device_is_available(d):
        if d.get("isAvailable") is True:
            return True
        avail = (d.get("availability") or "").lower()
        return ("available" in avail) and ("unavailable" not in avail)

    # Prefer Vision Pro devices
    candidates = [d for d in devs if device_is_available(d)]
    vp = [d for d in candidates if "vision pro" in (d.get("name") or "").lower()]
    chosen = vp[0] if vp else (candidates[0] if candidates else None)
    if chosen:
        udid = chosen.get("udid") or ""

print(runtime_id, udid)
PY
<<<"$SIMCTL_JSON")

if [[ -z "${XROS_RUNTIME_ID}" ]]; then
    echo "⚠ No AVAILABLE visionOS (xrOS) runtime found."
    echo "  This is OK for building the library - the SDK is sufficient."
    VISIONOS_SIM_UDID=""
else
    # If no device exists for the runtime, try to create one
    if [[ -z "${VISIONOS_SIM_UDID}" ]]; then
        echo "⚠ No available Vision Pro simulator device found for ${XROS_RUNTIME_ID}."
        echo "  Attempting to create one..."
        VISIONOS_SIM_UDID="$(xcrun simctl create "Vision Pro" com.apple.CoreSimulator.SimDeviceType.Apple-Vision-Pro "${XROS_RUNTIME_ID}" 2>/dev/null || true)"
    fi

    if [[ -n "${XROS_RUNTIME_ID}" ]]; then
        echo "✓ visionOS runtime: ${XROS_RUNTIME_ID}"
    fi
    if [[ -n "${VISIONOS_SIM_UDID}" ]]; then
        echo "✓ visionOS simulator device UDID: ${VISIONOS_SIM_UDID}"
    fi
fi

# Optional: boot the device (only if device is available and requested)
if [[ "${BOOT_SIM}" == "true" ]] && [[ -n "${VISIONOS_SIM_UDID}" ]]; then
    echo "Booting visionOS simulator..."
    xcrun simctl boot "${VISIONOS_SIM_UDID}" >/dev/null 2>&1 || true
    echo "✓ Boot requested (device may already be booted)"
fi

fi  # end of device selection block
else
    XROS_RUNTIME_ID=""
    VISIONOS_SIM_UDID=""
fi

# Export for downstream scripts (if they source this script)
export XROS_RUNTIME_ID
export VISIONOS_SIM_UDID

# ------------------------------
# Install vcpkg dependencies
# ------------------------------
if [ "$INSTALL_DEPS" = true ]; then
    echo ""
    echo "=== Installing vcpkg Dependencies ==="

    cd "$VCPKG_ROOT"

    # Bootstrap vcpkg if needed
    if [ ! -f "./vcpkg" ]; then
        ./bootstrap-vcpkg.sh
    fi

    PACKAGES=(
        "zlib:$TRIPLET"
        "zstd:$TRIPLET"
        "libpng:$TRIPLET"
        "freetype:$TRIPLET"
        "libzip:$TRIPLET"
        "bzip2:$TRIPLET"
        "brotli:$TRIPLET"
        "nlohmann-json:$TRIPLET"
    )

    for pkg in "${PACKAGES[@]}"; do
        echo "Installing $pkg..."
        ./vcpkg install "$pkg" --overlay-triplets=triplets/community || {
            echo "⚠ Failed to install $pkg - may need manual intervention"
        }
    done

    echo "✓ Dependencies installed"
    cd "$WORKSPACE"
fi

# ------------------------------
# Build ICU/libzip (optional)
# ------------------------------
if [ "$BUILD_ICU" = true ]; then
    if [ -f "$ICU_ROOT/lib/libicuuc.a" ]; then
        echo "✓ ICU already present at $ICU_ROOT"
    else
        echo ""
        echo "=== Building ICU (${BUILD_TARGET}) ==="
        if [[ "$BUILD_TARGET" == "device" ]]; then
            ./build-icu-visionos.sh --device
        else
            ./build-icu-visionos.sh --simulator
        fi
    fi
fi

if [ "$BUILD_LIBZIP" = true ]; then
    if [ -f "$LIBZIP_ROOT/lib/libzip.a" ]; then
        echo "✓ libzip already present at $LIBZIP_ROOT"
    else
        echo ""
        echo "=== Building libzip (${BUILD_TARGET}) ==="
        if [[ "$BUILD_TARGET" == "device" ]]; then
            ./build-libzip-visionos.sh --device
        else
            ./build-libzip-visionos.sh --simulator
        fi
    fi
fi

# ------------------------------
# Check dependencies exist
# ------------------------------
if [ "$SKIP_DEPS" = false ]; then
    if [ ! -d "$VCPKG_INSTALLED/lib" ]; then
        echo ""
        echo "❌ vcpkg dependencies not found at $VCPKG_INSTALLED"
        echo "   Run with --install-deps to install them, or --skip-deps to skip check"
        exit 1
    fi
    echo "✓ Using dependencies from: $VCPKG_INSTALLED"

    if [ ! -f "$LIBZIP_ROOT/lib/libzip.a" ]; then
        echo ""
        echo "❌ libzip not found at $LIBZIP_ROOT"
        echo "   Run: ./build-libzip-visionos.sh --${BUILD_TARGET}"
        exit 1
    fi
    echo "✓ Using libzip from: $LIBZIP_ROOT"

    if [ ! -f "$ICU_ROOT/lib/libicuuc.a" ]; then
        echo ""
        echo "❌ ICU not found at $ICU_ROOT"
        echo "   Run: ./build-icu-visionos.sh --${BUILD_TARGET}"
        exit 1
    fi
    echo "✓ Using ICU from: $ICU_ROOT"
fi

# ------------------------------
# Clean build directory if requested
# ------------------------------
if [ "$CLEAN_BUILD" = true ]; then
    echo ""
    echo "=== Cleaning Build Directory ==="
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ------------------------------
# Configure with CMake
# ------------------------------
echo ""
echo "=== Configuring CMake ==="

CMAKE_ARGS=(
    "$WORKSPACE"
    "-DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_FILE"
    "-DCMAKE_BUILD_TYPE=Release"

    # Dependency paths
    "-DCMAKE_PREFIX_PATH=$VCPKG_INSTALLED"
    "-DCMAKE_FIND_ROOT_PATH=$VCPKG_INSTALLED"

    # Library locations
    "-DFREETYPE_LIBRARY=$VCPKG_INSTALLED/lib/libfreetype.a"
    "-DFREETYPE_INCLUDE_DIRS=$VCPKG_INSTALLED/include"
    "-DZLIB_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    "-DZLIB_LIBRARY=$VCPKG_INSTALLED/lib/libz.a"
    "-DPNG_PNG_INCLUDE_DIR=$VCPKG_INSTALLED/include"
    "-DPNG_LIBRARY=$VCPKG_INSTALLED/lib/libpng16.a"
    "-DLIBZIP_LIBRARY=$LIBZIP_ROOT/lib/libzip.a"
    "-DLIBZIP_INCLUDE_DIR=$LIBZIP_ROOT/include"

    "-DOPENSSL_CRYPTO_LIBRARY=$VCPKG_INSTALLED/lib/libcrypto.a"
    "-DBZIP2_LIBRARY=$VCPKG_INSTALLED/lib/libbz2.a"
    "-DZSTD_LIBRARY=$VCPKG_INSTALLED/lib/libzstd.a"
    "-DZSTD_INCLUDE_DIR=$VCPKG_INSTALLED/include"

    # Disable SDL/GUI features (using native visionOS rendering)
    "-DDISABLE_GUI=ON"
    "-DDISABLE_SDL=ON"
    "-DDISABLE_DISCORD_RPC=ON"
    "-DDISABLE_OPENGL=ON"
    "-DDISABLE_HTTP=ON"
    "-DDISABLE_NETWORK=ON"
    "-DDISABLE_FLAC=ON"
    "-DDISABLE_VORBIS=ON"
    "-DENABLE_SCRIPTING=OFF"

    # Skip downloads (assets managed separately)
    "-DMACOS_USE_DEPENDENCIES=OFF"
    "-DDOWNLOAD_TITLE_SEQUENCES=OFF"
    "-DDOWNLOAD_OBJECTS=OFF"
    "-DDOWNLOAD_OPENSFX=OFF"
    "-DDOWNLOAD_OPENMSX=OFF"
)

# Add ICU if available
if [ -n "${ICU_ROOT}" ] && [ -d "${ICU_ROOT}" ]; then
    CMAKE_ARGS+=(
        "-DICU_ROOT=${ICU_ROOT}"
        "-DICU_INCLUDE_DIR=${ICU_ROOT}/include"
    )
fi

cmake "${CMAKE_ARGS[@]}"

# ------------------------------
# Build the library
# ------------------------------
echo ""
echo "=== Building libopenrct2.a ==="

NPROC="$(sysctl -n hw.ncpu)"
cmake --build . --target libopenrct2 -j"$NPROC"

# Check if build succeeded
if [ ! -f "$BUILD_DIR/libopenrct2.a" ]; then
    echo "❌ Build failed - libopenrct2.a not found"
    exit 1
fi

echo ""
echo "=============================================="
echo "Build Successful!"
echo "=============================================="
echo ""
echo "Library: $BUILD_DIR/libopenrct2.a"
echo ""
if [[ -n "${VISIONOS_SIM_UDID:-}" ]]; then
    echo "Selected visionOS simulator: $VISIONOS_SIM_UDID"
fi
if [[ -n "${XROS_RUNTIME_ID:-}" ]]; then
    echo "Selected visionOS runtime:   $XROS_RUNTIME_ID"
fi
echo ""
echo "Next steps:"
echo "  1. Add library to Xcode project:"
echo "     - Add libopenrct2.a to 'Link Binary With Libraries'"
echo "     - Add dependency .a files from $VCPKG_INSTALLED/lib"
echo ""
echo "  2. Add OPENRCT2_FULL_CONTEXT=1 to preprocessor definitions"
echo ""
echo "  3. Run ./prepare-visionos-app.sh to bundle game assets"
echo ""
