#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

MODE="${1:-verify}"
case "$MODE" in
    launch|logs|verify) ;;
    *)
        echo "Usage: $0 [launch|logs|verify]" >&2
        exit 2
        ;;
esac

BUNDLE_ID="org.openrct2.touch"
APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"
ARTIFACT_DIR="$ROOT/build/ios-sim"
LOG_PATH="$ARTIFACT_DIR/OpenRCT2Touch-lifecycle.log"
SCREENSHOT_PATH="$ARTIFACT_DIR/OpenRCT2Touch-missing-data.png"

find_ipad() {
    if [[ -n "${OPENRCT2_SIMULATOR_UDID:-}" ]]; then
        printf '%s\n' "$OPENRCT2_SIMULATOR_UDID"
        return
    fi

    xcrun simctl list devices available | awk '
        /iPad/ && /\([0-9A-F-]+\)/ {
            match($0, /\([0-9A-F-]+\)/)
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
        }
    '
}

create_ipad() {
    local runtime device_type
    runtime="$(xcrun simctl list runtimes | awk '
        /^iOS / && /com\.apple\.CoreSimulator\.SimRuntime\.iOS-/ && !/unavailable/ {
            print $NF
            exit
        }
    ')"
    device_type="$(xcrun simctl list devicetypes | awk '
        /^iPad Pro / && /com\.apple\.CoreSimulator\.SimDeviceType/ {
            line = $0
            sub(/^.*\(/, "", line)
            sub(/\)$/, "", line)
            print line
            exit
        }
    ')"

    if [[ -z "$runtime" || -z "$device_type" ]]; then
        echo "No installed iOS runtime and iPad device type are available." >&2
        echo "Install an iOS Simulator runtime from Xcode, then retry." >&2
        exit 1
    fi

    xcrun simctl create "OpenRCT2 Touch iPad" "$device_type" "$runtime"
}

boot_ipad() {
    local udid="$1"
    if ! xcrun simctl list devices | grep -F "$udid" | grep -q '(Booted)'; then
        xcrun simctl boot "$udid"
    fi
    xcrun simctl bootstatus "$udid" -b
}

launch_app() {
    local udid="$1"
    local output
    output="$(xcrun simctl launch "$udid" "$BUNDLE_ID")"
    printf '%s\n' "${output##*: }"
}

if [[ "$MODE" != "logs" ]]; then
    "$ROOT/scripts/check-repo-safety.sh"
    if [[ "${OPENRCT2_SKIP_BUILD:-0}" != "1" ]]; then
        "$ROOT/scripts/build-ios.sh" sim
    fi
    if [[ ! -d "$APP" ]]; then
        echo "Missing Simulator app bundle: $APP" >&2
        exit 1
    fi
fi

UDID="$(find_ipad)"
if [[ -z "$UDID" ]]; then
    UDID="$(create_ipad)"
fi
boot_ipad "$UDID"

if [[ "$MODE" == "logs" ]]; then
    exec xcrun simctl spawn "$UDID" log stream --style compact --level info \
        --predicate 'process == "OpenRCT2Touch"'
fi

xcrun simctl install "$UDID" "$APP"
mkdir -p "$ARTIFACT_DIR"

if [[ "$MODE" == "launch" ]]; then
    PID="$(launch_app "$UDID")"
    xcrun simctl io "$UDID" screenshot "$SCREENSHOT_PATH"
    echo "OpenRCT2 Touch launched on iPad Simulator $UDID with pid $PID."
    echo "Screenshot: $SCREENSHOT_PATH"
    echo "Stream logs with: $0 logs"
    exit 0
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
FIRST_PID="$(launch_app "$UDID")"
sleep 5
xcrun simctl io "$UDID" screenshot "$SCREENSHOT_PATH"

xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null
sleep 2
RESUMED_PID="$(launch_app "$UDID")"
sleep 2

if [[ "$FIRST_PID" != "$RESUMED_PID" ]]; then
    echo "OpenRCT2 Touch was replaced while backgrounded: $FIRST_PID -> $RESUMED_PID" >&2
    exit 1
fi

xcrun simctl spawn "$UDID" log show --style compact --last 3m \
    --predicate "processIdentifier == $FIRST_PID AND eventMessage CONTAINS \"lifecycle:\"" \
    > "$LOG_PATH"

for required_event in \
    'lifecycle: process-loaded' \
    'lifecycle: UIApplicationWillResignActiveNotification' \
    'lifecycle: UIApplicationDidEnterBackgroundNotification' \
    'lifecycle: UIApplicationWillEnterForegroundNotification'; do
    if ! grep -F "$required_event" "$LOG_PATH" >/dev/null; then
        echo "Missing lifecycle event: $required_event" >&2
        exit 1
    fi
done

ACTIVE_COUNT="$(grep -c 'lifecycle: UIApplicationDidBecomeActiveNotification' "$LOG_PATH" || true)"
if (( ACTIVE_COUNT < 2 )); then
    echo "Expected two active lifecycle events; found $ACTIVE_COUNT." >&2
    exit 1
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID"
FINAL_PID="$(launch_app "$UDID")"
if [[ "$FINAL_PID" == "$FIRST_PID" ]]; then
    echo "Termination verification did not produce a new process." >&2
    exit 1
fi

echo "OpenRCT2 Touch Simulator verification passed."
echo "Device: $UDID"
echo "Lifecycle process: $FIRST_PID"
echo "Relaunched process: $FINAL_PID"
echo "Lifecycle log: $LOG_PATH"
echo "Screenshot: $SCREENSHOT_PATH"
