#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"

find_ipad() {
    if [[ -n "${OPENRCT2_SIMULATOR_UDID:-}" ]]; then
        printf '%s\n' "$OPENRCT2_SIMULATOR_UDID"
        return
    fi

    xcrun simctl list devices available | awk '
        /^[[:space:]]+iPad([[:space:]]|$)/ && /\([0-9A-F-]+\)/ {
            match($0, /\([0-9A-F-]+\)/)
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
        }
    '
}

"$ROOT/scripts/check-repo-safety.sh"

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    echo "User-owned RCT2 data is missing Data/g1.dat: $RCT2_DATA" >&2
    exit 1
fi

SOURCE_ROOT="$(cd "$RCT2_DATA" && pwd -P)"
REF_ROOT="$(cd "$ROOT/ref" && pwd -P)"
case "$SOURCE_ROOT/" in
    "$REF_ROOT"/*) ;;
    *)
        echo "Refusing to seed from outside the repository's ignored ref directory: $SOURCE_ROOT" >&2
        exit 1
        ;;
esac

UDID="$(find_ipad)"
if [[ -z "$UDID" ]]; then
    echo "No available iPad Simulator is installed." >&2
    exit 1
fi

DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
case "$DATA_CONTAINER" in
    */data/Containers/Data/Application/*) ;;
    *)
        echo "Refusing unexpected Simulator data-container path: $DATA_CONTAINER" >&2
        exit 1
        ;;
esac

DESTINATION="$DATA_CONTAINER/Documents/rct2"
case "$DESTINATION" in
    *.app|*.app/*|*.ipa|*.ipa/*|*.xcarchive|*.xcarchive/*|*/Containers/Bundle/*)
        echo "Refusing to seed a distributable or bundle destination: $DESTINATION" >&2
        exit 1
        ;;
    "$DATA_CONTAINER"/Documents/rct2) ;;
    *)
        echo "Refusing unexpected Simulator seed destination: $DESTINATION" >&2
        exit 1
        ;;
esac

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
mkdir -p "$DESTINATION"

for item in Data ObjData Scenarios Tracks; do
    if [[ ! -d "$SOURCE_ROOT/$item" ]]; then
        echo "Required RCT2 directory is missing: $item" >&2
        exit 1
    fi
    ditto "$SOURCE_ROOT/$item" "$DESTINATION/$item"
done

if [[ -f "$SOURCE_ROOT/RCT2.EXE" ]]; then
    ditto "$SOURCE_ROOT/RCT2.EXE" "$DESTINATION/RCT2.EXE"
elif [[ -f "$SOURCE_ROOT/rct2.exe" ]]; then
    ditto "$SOURCE_ROOT/rct2.exe" "$DESTINATION/rct2.exe"
fi

if [[ ! -f "$DESTINATION/Data/g1.dat" ]]; then
    echo "Simulator seed failed to produce Data/g1.dat." >&2
    exit 1
fi

echo "User-owned RCT2 data was copied only to the installed Simulator sandbox."
echo "Device: $UDID"
echo "Destination: $DESTINATION"
du -sh "$DESTINATION"
