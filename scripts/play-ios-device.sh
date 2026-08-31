#!/usr/bin/env bash
set -euo pipefail

# One-command personal signed install on a connected iPhone or iPad.
# Prefers CJ's iPhone Air by default; use --ipad for CJ's iPad Pro, or --all for both.
# Team/UDID come from gitignored runtime/device.env.
# Copies ignored ref/rct2 into the .app before codesign so Files import is optional.
#
#   ./scripts/play-ios-device.sh
#   ./scripts/play-ios-device.sh --ipad
#   ./scripts/play-ios-device.sh --all
#   ./scripts/play-ios-device.sh --console   # stream device logs until the app exits

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

CONSOLE="${OPENRCT2_DEVICE_CONSOLE:-0}"
TARGET="${OPENRCT2_DEVICE_TARGET:-auto}"
CLI_TARGET_EXPLICIT=0
PINNED_UDID="${OPENRCT2_DEVICE_UDID:-}"
for argument in "$@"; do
    case "$argument" in
        --console)
            CONSOLE=1
            ;;
        --iphone)
            TARGET=iphone
            CLI_TARGET_EXPLICIT=1
            ;;
        --ipad)
            TARGET=ipad
            CLI_TARGET_EXPLICIT=1
            ;;
        --all)
            TARGET=all
            CLI_TARGET_EXPLICIT=1
            ;;
        --list)
            exec python3 "$SCRIPT_DIR/pick-ios-device.py" --list
            ;;
        -h|--help)
            cat <<'EOF'
Usage: ./scripts/play-ios-device.sh [--iphone | --ipad | --all] [--console] [--list]

Signs, installs, and launches OpenRCT2 Touch on a connected iPhone or iPad.

Device selection:
  (default)   prefers CJ's iPhone Air, then any iPhone, then any iPad
  --iphone    prefers CJ's iPhone Air, then any connected iPhone
  --ipad      prefers CJ's iPad Pro, then any connected iPad
  --all       build once, then install and launch on every connected device
  --list      print connected device names and UDIDs

  --iphone, --ipad, and --all override OPENRCT2_DEVICE_UDID in runtime/device.env.
  With no CLI target flag, a pinned OPENRCT2_DEVICE_UDID wins over OPENRCT2_DEVICE_TARGET.

First-time setup (once):
  mkdir -p runtime
  cp scripts/device.env.example runtime/device.env
  # Set OPENRCT2_DEVELOPMENT_TEAM in runtime/device.env
  # Optionally pin OPENRCT2_DEVICE_UDID or OPENRCT2_DEVICE_TARGET

Unlock the device before launch. Team and UDID stay out of git.
EOF
            exit 0
            ;;
        --*)
            echo "Unknown option: $argument" >&2
            echo "Usage: $0 [--iphone | --ipad | --all] [--console] [--list]" >&2
            exit 2
            ;;
        *)
            echo "Usage: $0 [--iphone | --ipad | --all] [--console] [--list]" >&2
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

pick_device_udids() {
    python3 "$SCRIPT_DIR/pick-ios-device.py" --target "$1"
}

read_device_udids() {
    local target="$1"
    DEVICE_UDIDS=()
    while IFS= read -r udid; do
        [[ -n "$udid" ]] || continue
        DEVICE_UDIDS+=("$udid")
    done < <(pick_device_udids "$target" || true)
}

device_label() {
    python3 "$SCRIPT_DIR/pick-ios-device.py" --list 2>/dev/null \
        | awk -v udid="$1" '$2 == udid { print $1; exit }'
}

if [[ "$CLI_TARGET_EXPLICIT" == "1" ]]; then
    if [[ -n "$PINNED_UDID" ]]; then
        echo "Using --$TARGET (ignoring OPENRCT2_DEVICE_UDID=$PINNED_UDID in runtime/device.env)"
    fi
    read_device_udids "$TARGET"
elif [[ -n "$PINNED_UDID" ]]; then
    DEVICE_UDIDS=("$PINNED_UDID")
    label="$(device_label "$PINNED_UDID")"
    if [[ -n "$label" ]]; then
        echo "Using pinned device from runtime/device.env: $label ($PINNED_UDID)"
    else
        echo "Using pinned device from runtime/device.env: $PINNED_UDID"
    fi
else
    read_device_udids "$TARGET"
fi

if [[ "${#DEVICE_UDIDS[@]}" -eq 0 ]]; then
    echo "No connected physical iPhone or iPad was found." >&2
    echo "Unlock the device, trust this Mac, and keep it on the same network or USB." >&2
    echo "Connected devices:" >&2
    python3 "$SCRIPT_DIR/pick-ios-device.py" --list >&2 || xcrun devicectl list devices >&2 || true
    exit 1
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

echo "Unlock the device if it is locked, then wait for the signed install."
export OPENRCT2_BUNDLE_LOCAL_RCT2=ON
"$ROOT/scripts/build-ios-device.sh" signed

for device_udid in "${DEVICE_UDIDS[@]}"; do
  label="$(device_label "$device_udid")"
  if [[ -n "$label" ]]; then
    echo "Installing on $label ($device_udid)"
  else
    echo "Installing on device $device_udid"
  fi
  OPENRCT2_DEVICE_UDID="$device_udid" "$ROOT/scripts/install-run-ios.sh" "$device_udid"
done
