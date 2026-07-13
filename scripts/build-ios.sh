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
    local binary="$app/OpenRCT2Touch"

    cmake --build "$build_root" --target openrct2-touch-stage

    plutil -lint "$app/Info.plist"
    if [[ "$(plutil -extract CFBundleIdentifier raw "$app/Info.plist")" != "org.openrct2.touch" ]]; then
        echo "Unexpected iOS bundle identifier." >&2
        exit 1
    fi

    for required_asset in g2.dat fonts.dat palettes.dat tracks.dat language/en-GB.txt; do
        if [[ ! -f "$app/$required_asset" ]]; then
            echo "App bundle is missing engine asset: $required_asset" >&2
            exit 1
        fi
    done

    local proprietary_matches
    proprietary_matches="$(find "$app" -type f -print | rg -i '(^|/)(g1\.dat|css1\.dat|css2\.dat|rct2\.exe)$|/(ObjData|Scenarios)/|\.(sv4|sv6|sc4|sc6|td4|td6)$' || true)"
    if [[ -n "$proprietary_matches" ]]; then
        echo "Proprietary game-data signature found in app bundle:" >&2
        echo "$proprietary_matches" >&2
        exit 1
    fi

    local unexpected_links
    unexpected_links="$(find "$app" -type l -print)"
    if [[ -n "$unexpected_links" ]]; then
        echo "Unexpected symbolic link found in app bundle:" >&2
        echo "$unexpected_links" >&2
        exit 1
    fi

    local bundled_file relative_path engine_source
    while IFS= read -r -d '' bundled_file; do
        relative_path="${bundled_file#"$app"/}"
        case "$relative_path" in
            Info.plist|OpenRCT2Touch)
                continue
                ;;
        esac

        engine_source="$ROOT/assets/engine/$relative_path"
        if [[ ! -f "$engine_source" ]]; then
            echo "App bundle contains a file outside the redistributable engine manifest: $relative_path" >&2
            exit 1
        fi
        if ! cmp -s "$engine_source" "$bundled_file"; then
            echo "Bundled engine asset differs from its redistributable source: $relative_path" >&2
            exit 1
        fi
    done < <(find "$app" -type f -print0)

    file "$binary"
    xcrun vtool -show-build "$binary"
    if ! xcrun vtool -show-build "$binary" | rg "platform $platform" >/dev/null; then
        echo "App binary has the wrong Apple platform identity; expected $platform." >&2
        exit 1
    fi

    echo "iOS app bundle passed for $platform: $app"
}

if [[ "$MODE" == "all" || "$MODE" == "device" ]]; then
    verify_bundle ios-arm64 IOS
fi
if [[ "$MODE" == "all" || "$MODE" == "sim" ]]; then
    verify_bundle ios-sim-arm64 IOSSIMULATOR
fi
