#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

MODE="${1:-verify}"
FAMILY="${2:-}"
case "$MODE" in
    launch|logs|verify) ;;
    *)
        echo "Usage: $0 [launch|logs|verify] [iphone|ipad|all]" >&2
        exit 2
        ;;
esac
if [[ -z "$FAMILY" ]]; then
    if [[ "$MODE" == "verify" ]]; then
        FAMILY="all"
    else
        FAMILY="ipad"
    fi
fi
case "$FAMILY" in
    iphone|ipad|all) ;;
    *)
        echo "Usage: $0 [launch|logs|verify] [iphone|ipad|all]" >&2
        exit 2
        ;;
esac

BUNDLE_ID="$OPENRCT2_TOUCH_BUNDLE_ID"
APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"
ARTIFACT_ROOT="$ROOT/build/ios-sim"

find_device() {
    local family="$1"
    local pattern

    if [[ -n "${OPENRCT2_SIMULATOR_UDID:-}" ]]; then
        printf '%s\n' "$OPENRCT2_SIMULATOR_UDID"
        return
    fi

    case "$family" in
        iphone) pattern='^[[:space:]]+iPhone([[:space:]]|$)' ;;
        ipad) pattern='^[[:space:]]+iPad([[:space:]]|$)' ;;
        *)
            echo "Unsupported Simulator family: $family" >&2
            exit 1
            ;;
    esac

    xcrun simctl list devices available | awk -v pattern="$pattern" '
        $0 ~ pattern && /\([0-9A-F-]+\)/ {
            match($0, /\([0-9A-F-]+\)/)
            print substr($0, RSTART + 1, RLENGTH - 2)
            exit
        }
    '
}

first_runtime() {
    xcrun simctl list runtimes | awk '
        /^iOS / && /com\.apple\.CoreSimulator\.SimRuntime\.iOS-/ && !/unavailable/ {
            print $NF
            exit
        }
    '
}

create_device() {
    local family="$1"
    local runtime device_type name
    runtime="$(first_runtime)"

    case "$family" in
        iphone)
            name="OpenRCT2 Touch iPhone"
            device_type="$(xcrun simctl list devicetypes | awk '
                /^iPhone / && /com\.apple\.CoreSimulator\.SimDeviceType/ && !/SE/ {
                    line = $0
                    sub(/^.*\(/, "", line)
                    sub(/\)$/, "", line)
                    print line
                    exit
                }
            ')"
            ;;
        ipad)
            name="OpenRCT2 Touch iPad"
            device_type="$(xcrun simctl list devicetypes | awk '
                /^iPad Pro / && /com\.apple\.CoreSimulator\.SimDeviceType/ {
                    line = $0
                    sub(/^.*\(/, "", line)
                    sub(/\)$/, "", line)
                    print line
                    exit
                }
            ')"
            ;;
        *)
            echo "Unsupported Simulator family: $family" >&2
            exit 1
            ;;
    esac

    if [[ -z "$runtime" || -z "$device_type" ]]; then
        echo "No installed iOS runtime and $family device type are available." >&2
        echo "Install an iOS Simulator runtime from Xcode, then retry." >&2
        exit 1
    fi

    xcrun simctl create "$name" "$device_type" "$runtime"
}

boot_device() {
    local udid="$1"
    if ! xcrun simctl list devices | grep -F "$udid" | grep -q '(Booted)'; then
        xcrun simctl boot "$udid"
    fi
    xcrun simctl bootstatus "$udid" -b
    open -a Simulator --args -CurrentDeviceUDID "$udid" >/dev/null 2>&1 || true
}

# DeviceHub (Xcode 27) replaced Simulator.app. There is no reliable simctl or
# AppleScript path that rotates the LCD; requestGeometryUpdate from Darwin
# notify was tried and killed the game when backgrounded. Portrait screenshots
# remain the automated proof. Landscape is allowed by Info.plist + SDL and
# proven on a physical rotate, or with verify-ios-screenshot.swift landscape
# when a host can actually rotate the Simulator display.
ensure_portrait() {
    :
}

launch_app() {
    local udid="$1"
    local output pid attempt
    output="$(xcrun simctl launch "$udid" "$BUNDLE_ID")"
    pid="${output##*: }"
    pid="${pid//$'\n'/}"
    pid="${pid// /}"
    # Swift stub `main` returns 0 immediately; require a real UIKit active event
    # from this PID before treating the launch as successful.
    for attempt in $(seq 1 20); do
        if xcrun simctl spawn "$udid" log show --style compact --last 30s --info \
            --predicate "processIdentifier == $pid AND eventMessage CONTAINS \"lifecycle: UIApplicationDidBecomeActiveNotification\"" \
            2>/dev/null | grep -F "lifecycle: UIApplicationDidBecomeActiveNotification" >/dev/null; then
            printf '%s\n' "$pid"
            return 0
        fi
        sleep 1
    done
    echo "OpenRCT2 Touch pid $pid never became active (process likely exited at main)." >&2
    return 1
}

capture_frame() {
    local udid="$1"
    local raw_path="$2"
    local output_path="$3"

    xcrun simctl io "$udid" screenshot "$raw_path"
    ditto "$raw_path" "$output_path"
}

wait_for_verified_frame() {
    local udid="$1"
    local raw_path="$2"
    local output_path="$3"
    local verification_log="$4"
    local attempt orientation

    for attempt in $(seq 1 12); do
        capture_frame "$udid" "$raw_path" "$output_path"
        for orientation in portrait landscape; do
            if xcrun --sdk macosx swift "$ROOT/scripts/verify-ios-screenshot.swift" "$raw_path" "$orientation" > "$verification_log" 2>&1; then
                cat "$verification_log"
                return 0
            fi
        done
        sleep 2
    done

    cat "$verification_log" >&2
    echo "No verified portrait or landscape game frame appeared within the Simulator timeout." >&2
    return 1
}

resolve_udid() {
    local family="$1"
    local udid
    udid="$(find_device "$family")"
    if [[ -z "$udid" ]]; then
        udid="$(create_device "$family")"
    fi
    printf '%s\n' "$udid"
}

verify_family() {
    local family="$1"
    local udid artifact_dir log_path
    local raw_screenshot screenshot resumed_raw resumed_screenshot
    local first_pid resumed_pid final_pid active_count required_event

    udid="$(resolve_udid "$family")"
    boot_device "$udid"
    ensure_portrait "$udid"

    artifact_dir="$ARTIFACT_ROOT/$family"
    log_path="$artifact_dir/OpenRCT2Touch-lifecycle.log"
    raw_screenshot="$artifact_dir/OpenRCT2Touch-frame-raw.png"
    screenshot="$artifact_dir/OpenRCT2Touch-frame.png"
    resumed_raw="$artifact_dir/OpenRCT2Touch-resumed-raw.png"
    resumed_screenshot="$artifact_dir/OpenRCT2Touch-resumed.png"

    xcrun simctl install "$udid" "$APP"
    mkdir -p "$artifact_dir"

    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    first_pid="$(launch_app "$udid")"
    sleep 3
    wait_for_verified_frame \
        "$udid" "$raw_screenshot" "$screenshot" \
        "$artifact_dir/OpenRCT2Touch-frame-check.log"

    xcrun simctl launch "$udid" com.apple.Preferences >/dev/null
    sleep 2
    resumed_pid="$(launch_app "$udid")"
    sleep 2
    wait_for_verified_frame \
        "$udid" "$resumed_raw" "$resumed_screenshot" \
        "$artifact_dir/OpenRCT2Touch-resumed-check.log"

    if [[ "$first_pid" != "$resumed_pid" ]]; then
        echo "OpenRCT2 Touch was replaced while backgrounded: $first_pid -> $resumed_pid" >&2
        exit 1
    fi

    xcrun simctl spawn "$udid" log show --style compact --last 3m --info \
        --predicate "processIdentifier == $first_pid AND eventMessage CONTAINS \"[OpenRCT2Touch]\"" \
        > "$log_path"

    for required_event in \
        'lifecycle: process-loaded' \
        'lifecycle: UIApplicationWillResignActiveNotification' \
        'lifecycle: UIApplicationDidEnterBackgroundNotification' \
        'lifecycle: UIApplicationWillEnterForegroundNotification'; do
        if ! grep -F "$required_event" "$log_path" >/dev/null; then
            echo "Missing lifecycle event: $required_event" >&2
            exit 1
        fi
    done

    for required_event in \
        'native chrome: attached SwiftUI park overlay' \
        'renderer: driver=metal' \
        'presentation: window_points=' \
        'safe_area_points=' \
        'safe-area: bounds_points=' \
        'sandbox: bundle_role=read_only documents_writable=1 support_writable=1 caches_writable=1' \
        'paths: documents='; do
        if ! grep -F "$required_event" "$log_path" >/dev/null; then
            echo "Missing presentation proof: $required_event" >&2
            exit 1
        fi
    done

    presentation_line="$(grep -F 'presentation: window_points=' "$log_path" | tail -1)"
    window_points="$(sed -n 's/.*window_points=\([0-9]*x[0-9]*\).*/\1/p' <<<"$presentation_line")"
    canvas_points="$(sed -n 's/.*canvas=\([0-9]*x[0-9]*\).*/\1/p' <<<"$presentation_line")"
    if [[ -z "$window_points" || "$window_points" != "$canvas_points" ]]; then
        echo "Canvas does not fill the window (expected no safe-area letterbox)." >&2
        echo "  $presentation_line" >&2
        exit 1
    fi

    found_landscape_canvas=0
    while IFS= read -r line; do
        points="$(sed -n 's/.*window_points=\([0-9]*x[0-9]*\).*/\1/p' <<<"$line")"
        canvas="$(sed -n 's/.*canvas=\([0-9]*x[0-9]*\).*/\1/p' <<<"$line")"
        width="${points%x*}"
        height="${points#*x}"
        if [[ -n "$width" && -n "$height" && "$width" -gt "$height" && "$points" == "$canvas" ]]; then
            found_landscape_canvas=1
            echo "Landscape full-window canvas observed in presentation logs: $points"
            break
        fi
    done < <(grep -F 'presentation: window_points=' "$log_path" || true)
    if [[ "$found_landscape_canvas" != 1 ]]; then
        echo "No landscape canvas in presentation logs (Simulator LCD rotation is not automated)."
    fi

    active_count="$(grep -c 'lifecycle: UIApplicationDidBecomeActiveNotification' "$log_path" || true)"
    if (( active_count < 2 )); then
        echo "Expected two active lifecycle events; found $active_count." >&2
        exit 1
    fi

    xcrun simctl terminate "$udid" "$BUNDLE_ID"
    final_pid="$(launch_app "$udid")"
    if [[ "$final_pid" == "$first_pid" ]]; then
        echo "Termination verification did not produce a new process." >&2
        exit 1
    fi
    sleep 2
    "$ROOT/scripts/verify-ios-sandbox.sh" "$udid"

    echo "OpenRCT2 Touch Simulator verification passed ($family)."
    echo "Device: $udid"
    echo "Lifecycle process: $first_pid"
    echo "Relaunched process: $final_pid"
    echo "Lifecycle log: $log_path"
    echo "Screenshot: $screenshot"
    echo "Resumed screenshot: $resumed_screenshot"
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
    "$ROOT/scripts/bundle-local-rct2.sh" "$APP"
fi

if [[ "$MODE" == "logs" ]]; then
    if [[ "$FAMILY" == "all" ]]; then
        echo "logs requires iphone or ipad, not all." >&2
        exit 2
    fi
    UDID="$(resolve_udid "$FAMILY")"
    boot_device "$UDID"
    exec xcrun simctl spawn "$UDID" log stream --style compact --level info \
        --predicate 'process == "OpenRCT2Touch"'
fi

if [[ "$MODE" == "launch" ]]; then
    if [[ "$FAMILY" == "all" ]]; then
        echo "launch requires iphone or ipad, not all." >&2
        exit 2
    fi
    UDID="$(resolve_udid "$FAMILY")"
    boot_device "$UDID"
    ensure_portrait "$UDID"
    xcrun simctl install "$UDID" "$APP"
    mkdir -p "$ARTIFACT_ROOT/$FAMILY"
    PID="$(launch_app "$UDID")"
    sleep 2
    capture_frame \
        "$UDID" \
        "$ARTIFACT_ROOT/$FAMILY/OpenRCT2Touch-frame-raw.png" \
        "$ARTIFACT_ROOT/$FAMILY/OpenRCT2Touch-frame.png"
    echo "OpenRCT2 Touch launched on $FAMILY Simulator $UDID with pid $PID."
    echo "Screenshot: $ARTIFACT_ROOT/$FAMILY/OpenRCT2Touch-frame.png"
    echo "Stream logs with: $0 logs $FAMILY"
    exit 0
fi

if [[ "$FAMILY" == "all" ]]; then
    if [[ -n "${OPENRCT2_SIMULATOR_UDID:-}" ]]; then
        echo "OPENRCT2_SIMULATOR_UDID cannot be combined with the all-device verify." >&2
        exit 2
    fi
    verify_family iphone
    verify_family ipad
else
    verify_family "$FAMILY"
fi
