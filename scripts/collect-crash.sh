#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

DEVICE="${1:-${OPENRCT2_DEVICE_UDID:-}}"
OUTPUT_DIR="${OPENRCT2_CRASH_OUTPUT_DIR:-$ROOT/runtime/device-crashes}"

if [[ -z "$DEVICE" ]]; then
    echo "Usage: OPENRCT2_DEVICE_UDID=<device-identifier> $0" >&2
    echo "Connected devices:" >&2
    xcrun devicectl list devices >&2 || true
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"
mkdir -p "$OUTPUT_DIR"

LIST_JSON="$(mktemp "${TMPDIR:-/tmp}/openrct2touch-crashes.XXXXXX")"
trap 'rm -f "$LIST_JSON"' EXIT

xcrun devicectl device info files \
    --device "$DEVICE" \
    --domain-type systemCrashLogs \
    --filter "Name BEGINSWITH 'OpenRCT2Touch'" \
    --json-output "$LIST_JSON" >/dev/null

CRASH_COUNT="$(plutil -extract result.files raw "$LIST_JSON")"
if [[ "$CRASH_COUNT" -eq 0 ]]; then
    echo "No OpenRCT2Touch crash report is available on device $DEVICE." >&2
    echo "Launch the app once, reproduce the crash, wait a few seconds, and rerun this command." >&2
    exit 1
fi

COPIED=0
for (( index = 0; index < CRASH_COUNT; index++ )); do
    IS_DIRECTORY="$(plutil -extract "result.files.$index.resources.isDirectory" raw "$LIST_JSON")"
    if [[ "$IS_DIRECTORY" == "true" ]]; then
        continue
    fi

    SOURCE="$(plutil -extract "result.files.$index.relativePath" raw "$LIST_JSON")"
    NAME="$(plutil -extract "result.files.$index.name" raw "$LIST_JSON")"
    case "$NAME" in
        OpenRCT2Touch*) ;;
        *) continue ;;
    esac

    xcrun devicectl device copy from \
        --device "$DEVICE" \
        --domain-type systemCrashLogs \
        --source "$SOURCE" \
        --destination "$OUTPUT_DIR/$NAME"
    COPIED=$((COPIED + 1))
done

if [[ "$COPIED" -eq 0 ]]; then
    echo "OpenRCT2Touch crash entries were listed, but none were downloadable files." >&2
    exit 1
fi

echo "Collected $COPIED OpenRCT2Touch crash report(s): $OUTPUT_DIR"
