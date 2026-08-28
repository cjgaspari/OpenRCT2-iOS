#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

DEVICE="${1:-${OPENRCT2_DEVICE_UDID:-}}"
APP="${OPENRCT2_DEVICE_APP:-$ROOT/build/ios-xcode-device/Release-iphoneos/OpenRCT2Touch.app}"
BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"
LOG_DIR="$ROOT/runtime/device-logs"
LOG_FILE="${OPENRCT2_DEVICE_LOG:-$LOG_DIR/OpenRCT2Touch-launch.log}"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: OPENRCT2_DEVICE_UDID=<device-identifier> $0" >&2
    echo "Connected devices:" >&2
    xcrun devicectl list devices >&2 || true
    exit 2
fi
if [[ ! -d "$APP" ]]; then
    echo "No signed iPad app is available at: $APP" >&2
    echo "The signed build must complete successfully before installation." >&2
    echo "Rerun the complete signed-build command from README step 4 and wait for" >&2
    echo "'Xcode iPadOS signed build passed.' before retrying." >&2
    exit 1
fi
if [[ ! -f "$APP/embedded.mobileprovision" || ! -f "$APP/_CodeSignature/CodeResources" ]]; then
    echo "The device app is not development-signed; refusing to install it." >&2
    exit 1
fi

"$ROOT/scripts/check-repo-safety.sh"
"$ROOT/scripts/verify-ios-bundle.sh" "$APP" IOS

xcrun devicectl device install app --device "$DEVICE" "$APP"
mkdir -p "$(dirname "$LOG_FILE")"
LAUNCH_ARGS=(device process launch --terminate-existing --device "$DEVICE" "$BUNDLE_ID")
if [[ "${OPENRCT2_DEVICE_CONSOLE:-1}" == "1" ]]; then
    LAUNCH_ARGS+=(--console)
    echo "Streaming launch output to $LOG_FILE"
else
    echo "Launching $BUNDLE_ID (logs: $LOG_FILE)"
fi
set +e
xcrun devicectl "${LAUNCH_ARGS[@]}" 2>&1 | tee "$LOG_FILE"
LAUNCH_STATUS="${PIPESTATUS[0]}"
set -e

if [[ "$LAUNCH_STATUS" -ne 0 ]]; then
    echo "Device launch exited $LAUNCH_STATUS. Console log: $LOG_FILE" >&2
    if grep -q 'Locked\|FBSOpenApplicationErrorDomain' "$LOG_FILE"; then
        echo "Unlock the iPhone, then rerun: ./scripts/play-ios-device.sh" >&2
    fi
    echo "After an app crash, collect the device report with:" >&2
    echo "  OPENRCT2_DEVICE_UDID=$DEVICE ./scripts/collect-crash.sh" >&2
fi
exit "$LAUNCH_STATUS"
