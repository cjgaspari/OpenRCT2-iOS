#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/env.sh"

BINARY="$MACOS_BUILD_DIR/install/bin/openrct2"

"$ROOT/scripts/check-repo-safety.sh"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$ROOT/scripts/build-macos.sh"
fi

mkdir -p "$USER_DATA" "$CACHE_DATA"

exec "$BINARY" \
    --rct2-data-path "$RCT2_DATA" \
    --openrct2-data-path "$OPENRCT2_DATA" \
    --user-data-path "$USER_DATA" \
    "$@"
