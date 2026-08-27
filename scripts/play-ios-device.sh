#!/usr/bin/env bash
set -euo pipefail

# One-command personal signed install on a connected iPhone or iPad.
# Prefers CJ's iPhone Air. Team/UDID come from gitignored runtime/device.env.
# Copies ignored ref/rct2 into the .app before codesign so Files import is optional.
#
#   ./scripts/play-ios-device.sh
#   ./scripts/play-ios-device.sh --console   # stream device logs until the app exits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

CONSOLE="${OPENRCT2_DEVICE_CONSOLE:-0}"
for argument in "$@"; do
    case "$argument" in
        --console)
            CONSOLE=1
            ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/play-ios-device.sh [--console]

Signs, installs, and launches OpenRCT2 Touch on the connected iPhone or iPad.

First-time setup (once):
  mkdir -p runtime
  cp scripts/device.env.example runtime/device.env
  # Set OPENRCT2_DEVELOPMENT_TEAM in runtime/device.env
  # Optionally pin OPENRCT2_DEVICE_UDID (otherwise prefers a connected iPhone Air)

Unlock the phone before launch. Team and UDID stay out of git.
EOF
            exit 0
            ;;
        *)
            echo "Usage: $0 [--console]" >&2
            exit 2
            ;;
    esac
done
export OPENRCT2_DEVICE_CONSOLE="$CONSOLE"

if [[ -z "${OPENRCT2_DEVELOPMENT_TEAM:-}" ]]; then
    echo "Missing OPENRCT2_DEVELOPMENT_TEAM." >&2
    echo "Copy scripts/device.env.example to runtime/device.env and set the team id." >&2
    echo "Find it with: security find-identity -v -p codesigning" >&2
    echo "The value in parentheses on an Apple Development or Developer ID identity is the team id." >&2
    echo "Or: OPENRCT2_DEVELOPMENT_TEAM=XXXXXXXXXX $0" >&2
    exit 2
fi

if [[ -z "${OPENRCT2_DEVICE_UDID:-}" ]]; then
    DEVICE_JSON="$(mktemp "${TMPDIR:-/tmp}/openrct2touch-devices.XXXXXX")"
    xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null
    OPENRCT2_DEVICE_UDID="$(python3 - "$DEVICE_JSON" <<'PY'
import json, sys
data = json.loads(open(sys.argv[1]).read())
devices = data.get("result", {}).get("devices") or []
candidates = []
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    connection = device.get("connectionProperties") or {}
    if hardware.get("reality") != "physical" or hardware.get("platform") != "iOS":
        continue
    if connection.get("tunnelState") == "unavailable":
        continue
    transport = connection.get("transportType")
    if not transport or transport == "sameMachine":
        continue
    name = props.get("name") or hardware.get("marketingName") or ""
    udid = hardware.get("udid")
    if not udid:
        continue
    rank = 0 if transport in ("wired", "local") else 1
    rank += 0 if "iPhone Air" in name else 1 if "iPhone" in name else 2
    candidates.append((rank, name, udid))
if not candidates:
    raise SystemExit
candidates.sort()
print(candidates[0][2])
PY
)"
    rm -f "$DEVICE_JSON"
    if [[ -z "${OPENRCT2_DEVICE_UDID}" ]]; then
        echo "No connected physical iPhone or iPad was found." >&2
        echo "Unlock the device, trust this Mac, and keep it on the same network or USB." >&2
        xcrun devicectl list devices >&2 || true
        exit 1
    fi
    export OPENRCT2_DEVICE_UDID
    echo "Using connected device $OPENRCT2_DEVICE_UDID"
fi

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    echo "Local RCT2 data is missing at $RCT2_DATA/Data/g1.dat" >&2
    echo "Copy your RCT2 folder to ref/rct2, or omit bundling and import via Files after install." >&2
    exit 1
fi

if [[ -f "$ROOT/assets/engine/g2.dat" ]]; then
    export OPENRCT2_SKIP_MACOS_BUILD="${OPENRCT2_SKIP_MACOS_BUILD:-1}"
fi

if [[ ! -f "$ROOT/vendor/ios-arm64/openrct2-arm64-ios/lib/libzstd.a" \
    || ! -d "$ROOT/vendor/ios-arm64/openrct2-arm64-ios/share/sdl2" ]]; then
    echo "Device dependencies are missing or incomplete. Building them once (this is slow)."
    "$ROOT/scripts/build-ios-deps.sh" device
fi

echo "Unlock the iPhone if it is locked, then wait for the signed install."
export OPENRCT2_BUNDLE_LOCAL_RCT2=ON
"$ROOT/scripts/build-ios-device.sh" signed
exec "$ROOT/scripts/install-run-ios.sh"
