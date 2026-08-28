#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/env.sh"

TICKS="${TICKS:-1000}"
BINARY="$MACOS_BUILD_DIR/install/bin/openrct2"
LOG_DIR="$USER_DATA/logs"
LOG_FILE="$LOG_DIR/macos-headless.log"

"$ROOT/scripts/check-repo-safety.sh"

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    printf 'ERROR: the optional macOS headless test requires user-owned RCT2 data at %s/Data/g1.dat\n' "$RCT2_DATA" >&2
    printf 'Set RCT2_DATA to the RCT2 installation root, then retry.\n' >&2
    printf 'This test is not required to build or install the iPad app.\n' >&2
    exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$ROOT/scripts/build-macos.sh"
fi

if [[ ! -x "$BINARY" ]]; then
    printf 'ERROR: macOS binary is missing: %s\n' "$BINARY" >&2
    exit 1
fi
if [[ ! -f "$SMOKE_PARK" ]]; then
    printf 'ERROR: smoke park is missing: %s\n' "$SMOKE_PARK" >&2
    exit 1
fi

mkdir -p "$USER_DATA" "$CACHE_DATA" "$LOG_DIR"

set +e
"$BINARY" \
    simulate "$SMOKE_PARK" "$TICKS" \
    --rct2-data-path "$RCT2_DATA" \
    --openrct2-data-path "$OPENRCT2_DATA" \
    --user-data-path "$USER_DATA" \
    2>&1 | tee "$LOG_FILE"
run_status="${PIPESTATUS[0]}"
set -e

if [[ "$run_status" -ne 0 ]]; then
    printf 'ERROR: headless simulation exited %s. See %s\n' "$run_status" "$LOG_FILE" >&2
    exit "$run_status"
fi

if grep -Eiq '(^|[^[:alpha:]])(fatal|assertion failed|segmentation fault)([^[:alpha:]]|$)' "$LOG_FILE"; then
    printf 'ERROR: fatal/assert signature found in %s\n' "$LOG_FILE" >&2
    exit 1
fi

checksum="$(awk '/^Completed: / { print $2 }' "$LOG_FILE" | tail -n 1)"
if [[ -z "$checksum" ]]; then
    printf 'ERROR: simulation completion marker missing from %s\n' "$LOG_FILE" >&2
    exit 1
fi
if [[ -n "$SMOKE_EXPECTED_CHECKSUM" && "$checksum" != "$SMOKE_EXPECTED_CHECKSUM" ]]; then
    printf 'ERROR: checksum mismatch: expected %s, got %s\n' "$SMOKE_EXPECTED_CHECKSUM" "$checksum" >&2
    exit 1
fi
if [[ ! -f "$USER_DATA/config.ini" ]]; then
    printf 'ERROR: repo-local config was not created at %s/config.ini\n' "$USER_DATA" >&2
    exit 1
fi

printf 'macOS headless smoke test passed (%s ticks, checksum %s).\n' "$TICKS" "$checksum"
