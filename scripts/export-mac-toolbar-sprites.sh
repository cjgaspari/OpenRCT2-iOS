#!/usr/bin/env bash
# Package cleaned native toolbar icons for Option 1 glass (g2 PNGs + WIDX aliases).
# Classic SPR_TOOLBAR_* CSG extraction is follow-up when a sprite dump path is ready.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/resources/g2/icons"
OUT="$ROOT/macos/platform/chrome/ToolbarSprites/cleaned"
mkdir -p "$OUT"

copy_alias() {
  local src=$1 dest=$2
  if [[ -f "$SRC/$src.png" ]]; then
    cp -f "$SRC/$src.png" "$OUT/$dest.png"
  fi
}

# Clean copies under original g2 names
for name in mute unmute fast_forward chat cheats news_messages multiplayer_toolbar \
  zoom_in zoom_out rotate_view_anti-clockwise view small_scenery paths; do
  copy_alias "$name" "$name"
done

# WIDX aliases (WindowTopToolbarWidgetIdx) for native icon mode lookups
copy_alias mute widx_2
copy_alias unmute widx_mute_off
copy_alias fast_forward widx_19
copy_alias chat widx_26
copy_alias cheats widx_20
copy_alias news_messages widx_24
copy_alias multiplayer_toolbar widx_25
copy_alias zoom_out widx_3
copy_alias zoom_in widx_4
copy_alias rotate_view_anti-clockwise widx_5
copy_alias view widx_7
copy_alias small_scenery widx_11
copy_alias paths widx_12

printf 'Exported cleaned toolbar sprites → %s (%s files)\n' "$OUT" "$(ls -1 "$OUT" | wc -l | tr -d ' ')"
