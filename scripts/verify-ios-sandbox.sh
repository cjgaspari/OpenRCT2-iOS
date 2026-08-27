#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"
UDID="${1:-${OPENRCT2_SIMULATOR_UDID:-}}"
APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"

if [[ -z "$UDID" ]]; then
    echo "Usage: $0 <simulator-udid>" >&2
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"

DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
BUNDLE_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" bundle)"
case "$DATA_CONTAINER" in
    */data/Containers/Data/Application/*) ;;
    *)
        echo "Unexpected Simulator data-container path: $DATA_CONTAINER" >&2
        exit 1
        ;;
esac

has_g1() {
    [[ -n "${1:-}" && -f "$1/Data/g1.dat" ]]
}

DOCUMENTS_RCT2_PATH="$DATA_CONTAINER/Documents/rct2"
if [[ "$BUNDLE_CONTAINER" == *.app ]]; then
    BUNDLE_RCT2_PATH="$BUNDLE_CONTAINER/rct2"
else
    BUNDLE_RCT2_PATH="$BUNDLE_CONTAINER/OpenRCT2Touch.app/rct2"
fi
if ! has_g1 "$BUNDLE_RCT2_PATH" && has_g1 "$BUNDLE_CONTAINER/rct2"; then
    BUNDLE_RCT2_PATH="$BUNDLE_CONTAINER/rct2"
fi

USER_PATH="$DATA_CONTAINER/Documents/OpenRCT2"
CONFIG_PATH="$DATA_CONTAINER/Library/Application Support/OpenRCT2/config.ini"
CACHE_PATH="$DATA_CONTAINER/Library/Caches/OpenRCT2"

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
RCT2_PATH=""
if has_g1 "$PERSISTED_RCT2_PATH"; then
    RCT2_PATH="$PERSISTED_RCT2_PATH"
elif has_g1 "$BUNDLE_RCT2_PATH"; then
    RCT2_PATH="$BUNDLE_RCT2_PATH"
elif has_g1 "$DOCUMENTS_RCT2_PATH"; then
    RCT2_PATH="$DOCUMENTS_RCT2_PATH"
else
    echo "Missing RCT2 data in the app bundle or Documents sandbox." >&2
    exit 1
fi

if ! has_g1 "$PERSISTED_RCT2_PATH"; then
    case "$PERSISTED_RCT2_PATH" in
        "$BUNDLE_RCT2_PATH"|"$DOCUMENTS_RCT2_PATH"|"$BUNDLE_CONTAINER/rct2"|"$BUNDLE_CONTAINER/OpenRCT2Touch.app/rct2")
            echo "Persisted game_path is a known RCT2 location without Data/g1.dat yet; using $RCT2_PATH."
            ;;
        *)
            echo "Persisted RCT2 path does not match the current app container." >&2
            echo "Expected: $RCT2_PATH" >&2
            echo "Actual:   $PERSISTED_RCT2_PATH" >&2
            exit 1
            ;;
    esac
fi

if [[ "$(plutil -extract UIFileSharingEnabled raw "$APP/Info.plist")" != "true" \
    || "$(plutil -extract LSSupportsOpeningDocumentsInPlace raw "$APP/Info.plist")" != "true" ]]; then
    echo "The iOS bundle does not expose Documents through Files." >&2
    exit 1
fi

echo "iOS sandbox verification passed."
echo "  user:   $USER_PATH"
echo "  config: $CONFIG_PATH"
echo "  cache:  $CACHE_PATH"
echo "  rct2:   $RCT2_PATH"
