#!/usr/bin/env bash

set -euo pipefail

# Desktop Mac pipeline — always derive paths from this script's repo, not a
# poisoned agent/shell ROOT/BUILD_ROOT (common when Cursor inherits another cwd).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
# Prefer repo-local build dir unless the caller explicitly overrides MACOS_BUILD_DIR
# after we set it; clear inherited BUILD_ROOT so env.sh cannot point at another tree.
unset BUILD_ROOT
# shellcheck disable=SC1091
source "$ROOT/scripts/env.sh"
export BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
export MACOS_BUILD_DIR="${MACOS_BUILD_DIR:-$BUILD_ROOT/macos}"
export OPENRCT2_DATA="${OPENRCT2_DATA:-$ROOT/assets/engine}"

INSTALL_DIR="$MACOS_BUILD_DIR/install"

"$ROOT/scripts/check-repo-safety.sh"
mkdir -p "$MACOS_BUILD_DIR" "$OPENRCT2_DATA"

# Liquid Glass Mac chrome (research/mac-liquid-glass): portable to stable 27.2.1+.
# Still the same desktop target: Ninja RelWithDebInfo, MACOS_BUNDLE=OFF.
# C++ gets -mmacosx-version-min from CMAKE_OSX_DEPLOYMENT_TARGET; Swift does not
# unless -target is set — without it swiftc defaults to SDK minos (27.3) and the
# final linked binary inherits that.
cmake -S "$ROOT" -B "$MACOS_BUILD_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_INSTALL_MESSAGE=LAZY \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=27.2.1 \
    -DCMAKE_Swift_FLAGS="-target arm64-apple-macosx27.2.1" \
    -DARCH=arm64 \
    -DMACOS_USE_DEPENDENCIES=ON \
    -DMACOS_BUNDLE=OFF \
    -DWITH_TESTS=OFF \
    -DDOWNLOAD_TITLE_SEQUENCES=ON \
    -DDOWNLOAD_OBJECTS=ON \
    -DDOWNLOAD_OPENSFX=ON \
    -DDOWNLOAD_OPENMUSIC=ON \
    "$@"

cmake --build "$MACOS_BUILD_DIR" --parallel
cmake -E rm -f "$INSTALL_DIR/bin/openrct2" "$INSTALL_DIR/bin/openrct2-cli"
cmake --install "$MACOS_BUILD_DIR"
cmake -E copy_directory "$INSTALL_DIR/share/openrct2" "$OPENRCT2_DATA"

test -x "$INSTALL_DIR/bin/openrct2"
test -f "$OPENRCT2_DATA/g2.dat"
test -d "$OPENRCT2_DATA/language"

printf 'macOS build passed.\n'
printf '  binary: %s\n' "$INSTALL_DIR/bin/openrct2"
printf '  engine data: %s\n' "$OPENRCT2_DATA"
printf '  deploy: macOS %s+\n' "27.2.1"
