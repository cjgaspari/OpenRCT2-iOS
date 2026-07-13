#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

VCPKG_COMMIT="f87344cac03158cbf1467264565f1fd36b382a24"
VCPKG_ROOT="$ROOT/vendor/vcpkg"
MODE="${1:-all}"

case "$MODE" in
    all|device|sim) ;;
    *)
        echo "Usage: $0 [all|device|sim]" >&2
        exit 2
        ;;
esac

"$ROOT/scripts/check-repo-safety.sh"

if [[ ! -d "$VCPKG_ROOT/.git" ]]; then
    git clone --filter=blob:none https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
fi

if [[ "$(git -C "$VCPKG_ROOT" rev-parse HEAD 2>/dev/null || true)" != "$VCPKG_COMMIT" ]]; then
    git -C "$VCPKG_ROOT" fetch --depth 1 origin "$VCPKG_COMMIT"
    git -C "$VCPKG_ROOT" checkout --detach "$VCPKG_COMMIT"
fi

if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi

build_slice() {
    local label="$1"
    local triplet="$2"
    local platform="$3"
    local install_root="$ROOT/vendor/$label"
    local build_root="$ROOT/build/ios-deps-smoke-$label"

    VCPKG_DISABLE_METRICS=1 "$VCPKG_ROOT/vcpkg" install \
        --triplet "$triplet" \
        --overlay-triplets="$ROOT/ios/vcpkg-triplets" \
        --x-manifest-root="$ROOT" \
        --x-install-root="$install_root" \
        --allow-unsupported

    cmake --fresh -S "$ROOT/ios/deps-smoke" -B "$build_root" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
        -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$ROOT/ios/toolchain/ios.toolchain.cmake" \
        -DOPENRCT2_IOS_PLATFORM="$platform" \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
        -DVCPKG_TARGET_TRIPLET="$triplet" \
        -DVCPKG_INSTALLED_DIR="$install_root" \
        -DVCPKG_MANIFEST_MODE=OFF
    cmake --build "$build_root" --target openrct2-ios-deps-smoke

    local binary="$build_root/openrct2-ios-deps-smoke.app/openrct2-ios-deps-smoke"
    file "$binary"
    xcrun vtool -show-build "$binary"
}

if [[ "$MODE" == "all" || "$MODE" == "device" ]]; then
    build_slice ios-arm64 openrct2-arm64-ios DEVICE
fi
if [[ "$MODE" == "all" || "$MODE" == "sim" ]]; then
    build_slice ios-sim-arm64 openrct2-arm64-ios-simulator SIMULATOR
fi

echo "iOS dependency smoke build passed for: $MODE"
