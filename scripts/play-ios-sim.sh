#!/usr/bin/env bash
set -euo pipefail

# One-click personal Simulator play: bundle ignored ref/rct2, open Simulator, install, launch.
# Rebuilds only when there is no .app yet, or when you pass --rebuild.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

FAMILY="iphone"
REBUILD=0
for argument in "$@"; do
    case "$argument" in
        iphone|ipad)
            FAMILY="$argument"
            ;;
        --rebuild)
            REBUILD=1
            ;;
        *)
            echo "Usage: $0 [iphone|ipad] [--rebuild]" >&2
            exit 2
            ;;
    esac
done

APP="$ROOT/build/ios-libs-ios-sim-arm64/OpenRCT2Touch.app"

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    echo "Local RCT2 data is missing at $RCT2_DATA/Data/g1.dat" >&2
    echo "Copy your RCT2 folder to ref/rct2 (Data, ObjData, Scenarios, Tracks)." >&2
    exit 1
fi

if [[ ! -d "$ROOT/vendor/ios-sim-arm64/openrct2-arm64-ios-simulator" ]]; then
    echo "Simulator dependencies are missing. Building them once (this is slow)."
    "$ROOT/scripts/build-ios-deps.sh" sim
fi

if [[ "$REBUILD" -eq 1 || ! -d "$APP" ]]; then
    unset OPENRCT2_SKIP_BUILD
else
    export OPENRCT2_SKIP_BUILD=1
    echo "Reusing $APP (pass --rebuild after code changes)."
fi

exec "$ROOT/scripts/run-ios-sim.sh" launch "$FAMILY"
