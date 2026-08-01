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

BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"
APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"
ARTIFACT_DIR="$ROOT/build/ios-sim"
LOG_PATH="$ARTIFACT_DIR/OpenRCT2Touch-lifecycle.log"
RAW_SCREENSHOT_PATH="$ARTIFACT_DIR/OpenRCT2Touch-frame-raw.png"
SCREENSHOT_PATH="$ARTIFACT_DIR/OpenRCT2Touch-frame.png"
RESUMED_RAW_SCREENSHOT_PATH="$ARTIFACT_DIR/OpenRCT2Touch-resumed-raw.png"
RESUMED_SCREENSHOT_PATH="$ARTIFACT_DIR/OpenRCT2Touch-resumed.png"

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

capture_frame() {
    local udid="$1"
    local raw_path="$2"
    local output_path="$3"
    local width height

    xcrun simctl io "$udid" screenshot "$raw_path"
    width="$(sips -g pixelWidth "$raw_path" | awk '/pixelWidth:/ { print $2 }')"
    height="$(sips -g pixelHeight "$raw_path" | awk '/pixelHeight:/ { print $2 }')"
    if (( width < height )); then
        sips -r 90 "$raw_path" --out "$output_path" >/dev/null
    else
        ditto "$raw_path" "$output_path"
    fi
}

wait_for_verified_frame() {
    local udid="$1"
    local raw_path="$2"
    local output_path="$3"
    local verification_log="$4"
    local attempt

    for attempt in {1..12}; do
        capture_frame "$udid" "$raw_path" "$output_path"
        if xcrun --sdk macosx swift "$ROOT/scripts/verify-ios-screenshot.swift" "$raw_path" > "$verification_log" 2>&1; then
            cat "$verification_log"
            return 0
        fi
        sleep 2
    done

    cat "$verification_log" >&2
    echo "No verified game frame appeared within the Simulator timeout." >&2
    return 1
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
    sleep 2
    capture_frame "$UDID" "$RAW_SCREENSHOT_PATH" "$SCREENSHOT_PATH"
    echo "OpenRCT2 Touch launched on iPad Simulator $UDID with pid $PID."
    echo "Screenshot: $SCREENSHOT_PATH"
    echo "Stream logs with: $0 logs"
    exit 0
fi

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
FIRST_PID="$(launch_app "$UDID")"
sleep 3
wait_for_verified_frame "$UDID" "$RAW_SCREENSHOT_PATH" "$SCREENSHOT_PATH" "$ARTIFACT_DIR/OpenRCT2Touch-frame-check.log"

xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null
sleep 2
RESUMED_PID="$(launch_app "$UDID")"
sleep 2
wait_for_verified_frame \
    "$UDID" "$RESUMED_RAW_SCREENSHOT_PATH" "$RESUMED_SCREENSHOT_PATH" \
    "$ARTIFACT_DIR/OpenRCT2Touch-resumed-check.log"

if [[ "$FIRST_PID" != "$RESUMED_PID" ]]; then
    echo "OpenRCT2 Touch was replaced while backgrounded: $FIRST_PID -> $RESUMED_PID" >&2
    exit 1
fi

xcrun simctl spawn "$UDID" log show --style compact --last 3m --info \
    --predicate "processIdentifier == $FIRST_PID AND eventMessage CONTAINS \"[OpenRCT2Touch]\"" \
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

for required_event in \
    'renderer: driver=metal' \
    'presentation: window_points=' \
    'safe-area: bounds_points=' \
    'sandbox: bundle_role=read_only documents_writable=1 support_writable=1 caches_writable=1' \
    'paths: documents='; do
    if ! grep -F "$required_event" "$LOG_PATH" >/dev/null; then
        echo "Missing presentation proof: $required_event" >&2
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
sleep 2
"$ROOT/scripts/verify-ios-sandbox.sh" "$UDID"

echo "OpenRCT2 Touch Simulator verification passed."
echo "Device: $UDID"
echo "Lifecycle process: $FIRST_PID"
echo "Relaunched process: $FINAL_PID"
echo "Lifecycle log: $LOG_PATH"
echo "Screenshot: $SCREENSHOT_PATH"
echo "Resumed screenshot: $RESUMED_SCREENSHOT_PATH"
