#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

DEVICE="${1:-${OPENRCT2_DEVICE_UDID:-}}"
APP="${OPENRCT2_DEVICE_APP:-$ROOT/build/ios-xcode-device/Release-iphoneos/OpenRCT2Touch.app}"
BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: OPENRCT2_DEVICE_UDID=<device-identifier> $0" >&2
    echo "Connected devices:" >&2
    xcrun devicectl list devices >&2 || true
    exit 2
fi
if [[ ! -d "$APP" ]]; then
    echo "Missing signed app: $APP" >&2
    echo "Build it with OPENRCT2_DEVELOPMENT_TEAM=<team> ./scripts/build-ios-device.sh signed" >&2
    exit 1
fi
if [[ ! -f "$APP/embedded.mobileprovision" || ! -f "$APP/_CodeSignature/CodeResources" ]]; then
    echo "The device app is not development-signed; refusing to install it." >&2
    exit 1
fi

"$ROOT/scripts/check-repo-safety.sh"
"$ROOT/scripts/verify-ios-bundle.sh" "$APP" IOS

xcrun devicectl device install app --device "$DEVICE" "$APP"
exec xcrun devicectl device process launch \
    --console \
    --terminate-existing \
    --device "$DEVICE" \
    "$BUNDLE_ID"
