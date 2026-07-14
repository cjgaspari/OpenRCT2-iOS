#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

APP="${1:-}"
PLATFORM="${2:-}"

if [[ -z "$APP" || ! -d "$APP" || ( "$PLATFORM" != "IOS" && "$PLATFORM" != "IOSSIMULATOR" ) ]]; then
    echo "Usage: $0 <OpenRCT2Touch.app> <IOS|IOSSIMULATOR>" >&2
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"

BINARY="$APP/OpenRCT2Touch"
plutil -lint "$APP/Info.plist"
if [[ "$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")" != "org.openrct2.touch" ]]; then
    echo "Unexpected iOS bundle identifier." >&2
    exit 1
fi

for required_asset in g2.dat fonts.dat palettes.dat tracks.dat language/en-GB.txt; do
    if [[ ! -f "$APP/$required_asset" ]]; then
        echo "App bundle is missing engine asset: $required_asset" >&2
        exit 1
    fi
done

PROPRIETARY_MATCHES="$(
    find "$APP" -type f -print \
        | rg -i '(^|/)(g1\.dat|css1\.dat|css2\.dat|rct2\.exe)$|/(ObjData|Scenarios)/|\.(sv4|sv6|sc4|sc6|td4|td6)$' \
        || true
)"
if [[ -n "$PROPRIETARY_MATCHES" ]]; then
    echo "Proprietary game-data signature found in app bundle:" >&2
    echo "$PROPRIETARY_MATCHES" >&2
    exit 1
fi

UNEXPECTED_LINKS="$(find "$APP" -type l -print)"
if [[ -n "$UNEXPECTED_LINKS" ]]; then
    echo "Unexpected symbolic link found in app bundle:" >&2
    echo "$UNEXPECTED_LINKS" >&2
    exit 1
fi

while IFS= read -r -d '' bundled_file; do
    relative_path="${bundled_file#"$APP"/}"
    case "$relative_path" in
        Info.plist|OpenRCT2Touch|embedded.mobileprovision|_CodeSignature/CodeResources)
            continue
            ;;
        PkgInfo)
            if ! cmp -s <(printf 'APPL????') "$bundled_file"; then
                echo "Unexpected iOS PkgInfo contents." >&2
                exit 1
            fi
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
done < <(find "$APP" -type f -print0)

file "$BINARY"
xcrun vtool -show-build "$BINARY"
if ! xcrun vtool -show-build "$BINARY" | rg "platform $PLATFORM" >/dev/null; then
    echo "App binary has the wrong Apple platform identity; expected $PLATFORM." >&2
    exit 1
fi

if [[ -d "$APP/_CodeSignature" ]]; then
    codesign --verify --deep --strict --verbose=2 "$APP"
fi

echo "iOS app bundle passed for $PLATFORM: $APP"
