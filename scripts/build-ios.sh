#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

MODE="${1:-sim}"
case "$MODE" in
    all|device|sim) ;;
    *)
        echo "Usage: $0 [all|device|sim]" >&2
        exit 2
        ;;
esac

"$ROOT/scripts/check-repo-safety.sh"
"$ROOT/scripts/build-macos.sh"
"$ROOT/scripts/build-ios-libs.sh" "$MODE"

for required_asset in g2.dat fonts.dat palettes.dat tracks.dat language/en-GB.txt; do
    if [[ ! -f "$ROOT/assets/engine/$required_asset" ]]; then
        echo "Missing redistributable engine asset: assets/engine/$required_asset" >&2
        exit 1
    fi
done

verify_bundle() {
    local label="$1"
    local platform="$2"
    local build_root="$ROOT/build/ios-libs-$label"
    local app="$build_root/OpenRCT2Touch.app"

    cmake --build "$build_root" --target openrct2-touch-stage
    "$ROOT/scripts/verify-ios-bundle.sh" "$app" "$platform"
}

if [[ "$MODE" == "all" || "$MODE" == "device" ]]; then
    verify_bundle ios-arm64 IOS
fi
if [[ "$MODE" == "all" || "$MODE" == "sim" ]]; then
    verify_bundle ios-sim-arm64 IOSSIMULATOR
fi
