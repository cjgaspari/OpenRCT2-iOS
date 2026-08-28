#!/usr/bin/env bash
set -euo pipefail

# Copy user-owned RCT2 data into a local .app for personal Simulator installs.
# This does not track, commit, or package an IPA. Signed device builds must not
# be modified after codesign.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "Usage: $0 <OpenRCT2Touch.app>" >&2
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    echo "No local RCT2 data at $RCT2_DATA; skipping bundle copy."
    exit 0
fi

APP_ROOT="$(cd "$APP" && pwd -P)"
BUILD_ROOT="$(cd "$ROOT/build" && pwd -P)"
case "$APP_ROOT/" in
    "$BUILD_ROOT"/*) ;;
    *)
        echo "Refusing to copy RCT2 data outside the local build directory: $APP_ROOT" >&2
        exit 1
        ;;
esac
case "$APP_ROOT" in
    *.ipa|*.ipa/*|*.xcarchive|*.xcarchive/*)
        echo "Refusing to copy RCT2 data into an IPA or archive." >&2
        exit 1
        ;;
esac

SOURCE_ROOT="$(cd "$RCT2_DATA" && pwd -P)"
REF_ROOT="$(cd "$ROOT/ref" && pwd -P)"
case "$SOURCE_ROOT/" in
    "$REF_ROOT"/*) ;;
    *)
        echo "Refusing to copy RCT2 data from outside ignored ref/: $SOURCE_ROOT" >&2
        exit 1
        ;;
esac

DESTINATION="$APP_ROOT/rct2"
if [[ -f "$DESTINATION/Data/g1.dat" ]]; then
    echo "Local RCT2 data already present in $DESTINATION"
    exit 0
fi

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
    echo "Failed to copy Data/g1.dat into the local app bundle." >&2
    exit 1
fi

echo "Copied local RCT2 data into the Simulator app for personal use only."
echo "Destination: $DESTINATION"
du -sh "$DESTINATION"
