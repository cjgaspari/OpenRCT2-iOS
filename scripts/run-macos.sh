#!/usr/bin/env bash

set -euo pipefail

# Desktop Mac pipeline runner (not iOS Touch). Same binary as build-macos.sh.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
unset BUILD_ROOT
# shellcheck disable=SC1091
source "$ROOT/scripts/env.sh"
export BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
export MACOS_BUILD_DIR="${MACOS_BUILD_DIR:-$BUILD_ROOT/macos}"
export OPENRCT2_DATA="${OPENRCT2_DATA:-$ROOT/assets/engine}"
export USER_DATA="${USER_DATA:-$ROOT/runtime/user}"
export CACHE_DATA="${CACHE_DATA:-$ROOT/runtime/cache}"

BINARY="$MACOS_BUILD_DIR/install/bin/openrct2"

"$ROOT/scripts/check-repo-safety.sh"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$ROOT/scripts/build-macos.sh"
fi

mkdir -p "$USER_DATA" "$CACHE_DATA"

# openrct2 CLI contract: <uri> [options] — positional park/scenario first.
uri_args=()
opt_args=(
    --rct2-data-path="$RCT2_DATA"
    --openrct2-data-path="$OPENRCT2_DATA"
    --user-data-path="$USER_DATA"
)
for arg in "$@"; do
    if [[ "$arg" == -* ]]; then
        opt_args+=("$arg")
    else
        uri_args+=("$arg")
    fi
done

exec "$BINARY" "${uri_args[@]}" "${opt_args[@]}"
