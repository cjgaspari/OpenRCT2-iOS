# Toolbar sprites (Option 1 native icons)

`cleaned/` holds packaged PNGs for Liquid Glass toolbar buttons.

- **Source today:** `resources/g2/icons/` (mute, zoom, view, etc.) plus WIDX aliases (`widx_<n>.png`).
- **Still missing:** classic CSG `SPR_TOOLBAR_*` (pause, file, land, water, …) — SF Symbols used until exported.

Regenerate:

```bash
./scripts/export-mac-toolbar-sprites.sh
```

Toggle at runtime: File menu → Toolbar Icons → SF Symbols / In-game Icons.
