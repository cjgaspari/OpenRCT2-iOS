#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

BUNDLE_ID="org.openrct2.touch"
UDID="${1:-${OPENRCT2_SIMULATOR_UDID:-}}"
APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"

if [[ -z "$UDID" ]]; then
    echo "Usage: $0 <simulator-udid>" >&2
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"

DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
case "$DATA_CONTAINER" in
    */data/Containers/Data/Application/*) ;;
    *)
        echo "Unexpected Simulator data-container path: $DATA_CONTAINER" >&2
        exit 1
        ;;
esac

RCT2_PATH="$DATA_CONTAINER/Documents/rct2"
USER_PATH="$DATA_CONTAINER/Documents/OpenRCT2"
CONFIG_PATH="$DATA_CONTAINER/Library/Application Support/OpenRCT2/config.ini"
CACHE_PATH="$DATA_CONTAINER/Library/Caches/OpenRCT2"

if [[ ! -f "$RCT2_PATH/Data/g1.dat" ]]; then
    echo "Missing developer-seeded RCT2 data in the installed sandbox." >&2
    exit 1
fi
if [[ ! -d "$USER_PATH/plugin" || ! -d "$USER_PATH/save" ]]; then
    echo "OpenRCT2 did not create its user-visible Documents directories." >&2
    exit 1
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "OpenRCT2 did not write its private Application Support config." >&2
    exit 1
fi
if [[ ! -f "$CACHE_PATH/objects.idx" || ! -f "$CACHE_PATH/scenarios.idx" ]]; then
    echo "OpenRCT2 did not write its private cache indexes." >&2
    exit 1
fi

PERSISTED_RCT2_PATH="$(sed -n 's/^game_path = "\(.*\)"/\1/p' "$CONFIG_PATH")"
if [[ "$PERSISTED_RCT2_PATH" != "$RCT2_PATH" ]]; then
    echo "Persisted RCT2 path does not match the current app container." >&2
    echo "Expected: $RCT2_PATH" >&2
    echo "Actual:   $PERSISTED_RCT2_PATH" >&2
    exit 1
fi

if [[ "$(plutil -extract UIFileSharingEnabled raw "$APP/Info.plist")" != "true" \
    || "$(plutil -extract LSSupportsOpeningDocumentsInPlace raw "$APP/Info.plist")" != "true" ]]; then
    echo "The iOS bundle does not expose Documents through Files." >&2
    exit 1
fi

if find "$APP" -type f \( -iname 'g1.dat' -o -iname 'rct2.exe' -o -iname '*.sv6' -o -iname '*.sc6' \) -print -quit \
    | grep -q .; then
    echo "Proprietary RCT2 data entered the Simulator app bundle." >&2
    exit 1
fi

echo "iOS sandbox verification passed."
echo "  user:   $USER_PATH"
echo "  config: $CONFIG_PATH"
echo "  cache:  $CACHE_PATH"
echo "  rct2:   $RCT2_PATH"
