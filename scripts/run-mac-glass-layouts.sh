#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/macos/mockups/MacLiquidGlassLayouts"
cd "$PKG"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MacLiquidGlassLayouts"
exec open -n "$BIN" --args "$@" 2>/dev/null || exec "$BIN" "$@"
