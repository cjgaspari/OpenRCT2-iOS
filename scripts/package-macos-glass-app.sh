#!/usr/bin/env bash
# Assemble OpenRCT2-Glass.app from the current macOS install tree (MACOS_BUNDLE=OFF tip)
# and emit a portable OpenRCT2-Glass.zip next to it (ditto; preserves +x).
#
# Usage:
#   ./scripts/package-macos-glass-app.sh              # rebuild .app + zip
#   ./scripts/package-macos-glass-app.sh --zip-only   # zip existing .app only
#   ./scripts/package-macos-glass-app.sh /path/App.app
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_BUILD_DIR="${MACOS_BUILD_DIR:-$ROOT/build/macos}"
INSTALL_DIR="${INSTALL_DIR:-$MACOS_BUILD_DIR/install}"
ZIP_ONLY=0
APP="$MACOS_BUILD_DIR/OpenRCT2-Glass.app"
for arg in "$@"; do
    case "$arg" in
        --zip-only) ZIP_ONLY=1 ;;
        -*) echo "Unknown option: $arg" >&2; exit 2 ;;
        *) APP="$arg" ;;
    esac
done
BIN_SRC="$INSTALL_DIR/bin/openrct2"
DATA_SRC="$INSTALL_DIR/share/openrct2"
LIB_SRC="$INSTALL_DIR/lib"
ICON_SRC="$ROOT/resources/mac/openrct2.icns"
ASSETS_CAR="$ROOT/resources/mac/Assets.car"
EXE_NAME="OpenRCT2-Glass"
SHORT_SHA="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo tip)"
VERSION_TAG="$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo tip)"
ZIP_PATH="$(dirname "$APP")/OpenRCT2-Glass.zip"

glass_app_in_use() {
    # Don't delete/rebuild the bundle if a live process has the binary open.
    pgrep -f "$APP/Contents/MacOS/$EXE_NAME" >/dev/null 2>&1
}

write_portable_zip() {
    local app="$1"
    local zip="$2"
    local verify_dir
    [[ -d "$app/Contents/MacOS" ]] || { echo "Not an app bundle: $app" >&2; exit 1; }
    [[ -x "$app/Contents/MacOS/$EXE_NAME" ]] || { echo "Missing executable: $app/Contents/MacOS/$EXE_NAME" >&2; exit 1; }

    # Fresh ad-hoc sign so the sealed bundle is coherent after any local edits.
    codesign --force --deep -s - "$app" >/dev/null

    rm -f "$zip"
    # ditto keeps Unix modes (+x) and AppleDouble; Finder "Compress" of a whole
    # CMake build tree is what produced the confusing loose openrct2 siblings.
    ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

    verify_dir="$(mktemp -d /tmp/OpenRCT2-Glass-zip-verify.XXXXXX)"
    ditto -x -k "$zip" "$verify_dir"
    local vexe="$verify_dir/OpenRCT2-Glass.app/Contents/MacOS/$EXE_NAME"
    [[ -x "$vexe" ]] || { echo "Zip verify failed: executable lost +x" >&2; exit 1; }
    file "$vexe" | grep -q 'Mach-O 64-bit executable arm64' \
        || { echo "Zip verify failed: expected arm64 Mach-O" >&2; exit 1; }
    codesign --verify --deep --strict "$verify_dir/OpenRCT2-Glass.app" >/dev/null
    rm -rf "$verify_dir"

    printf 'Zipped %s\n' "$zip"
    printf '  requires: macOS 27.2.1+ / arm64 (Apple Silicon)\n'
    printf '  copy: AirDrop/scp the zip only — not the whole build/macos tree\n'
    printf '  other Mac: unzip, then open OpenRCT2-Glass.app\n'
    printf '  if the other Mac still blocks: right-click → Open, or: xattr -dr com.apple.quarantine OpenRCT2-Glass.app\n'
}

if [[ "$ZIP_ONLY" -eq 1 ]]; then
    write_portable_zip "$APP" "$ZIP_PATH"
    exit 0
fi

[[ -x "$BIN_SRC" ]] || { echo "Missing binary: $BIN_SRC (build with scripts/build-macos.sh first)" >&2; exit 1; }
[[ -d "$DATA_SRC" ]] || { echo "Missing engine data: $DATA_SRC" >&2; exit 1; }
[[ -d "$LIB_SRC" ]] || { echo "Missing install libs: $LIB_SRC" >&2; exit 1; }

if glass_app_in_use; then
    echo "OpenRCT2-Glass is running from $APP — skipping rebuild; writing zip only." >&2
    write_portable_zip "$APP" "$ZIP_PATH"
    exit 0
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$BIN_SRC" "$APP/Contents/MacOS/$EXE_NAME"
chmod +x "$APP/Contents/MacOS/$EXE_NAME"

# Engine data → Resources (Platform.macOS GetBundlePath)
rsync -a --delete \
    --exclude '.DS_Store' \
    "$DATA_SRC/" "$APP/Contents/Resources/"

[[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$APP/Contents/Resources/openrct2.icns"
[[ -f "$ASSETS_CAR" ]] && cp "$ASSETS_CAR" "$APP/Contents/Resources/Assets.car"

printf 'APPL????' >"$APP/Contents/PkgInfo"

# Minimal Info.plist — Liquid Glass research build identity
cat >"$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>${EXE_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>io.openrct2.OpenRCT2.Glass</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>OpenRCT2-Glass</string>
	<key>CFBundleDisplayName</key>
	<string>OpenRCT2 Glass</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION_TAG}</string>
	<key>CFBundleVersion</key>
	<string>${SHORT_SHA}</string>
	<key>CFBundleSignature</key>
	<string>ORCT</string>
	<key>LSMinimumSystemVersion</key>
	<string>27.2.1</string>
	<key>NSHumanReadableCopyright</key>
	<string>OpenRCT2 is licensed under the GNU General Public License version 3</string>
	<key>CFBundleIconFile</key>
	<string>openrct2.icns</string>
	<key>CFBundleIconName</key>
	<string>openrct2</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

# Bundle @rpath dylibs into Frameworks and point the executable at them.
# Prefer -add_rpath / -delete_rpath over fixup_bundle: the tip binary was linked
# without -headerpad_max_install_names, so install_name_tool -change fails.
EXE="$APP/Contents/MacOS/$EXE_NAME"
FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS"

# Direct + transitive @rpath deps from the tip install tree.
while IFS= read -r dep; do
    base="$(basename "$dep")"
    src=""
    if [[ -f "$LIB_SRC/$base" ]]; then
        src="$LIB_SRC/$base"
    elif [[ -f "$ROOT/lib/macos/lib/$base" ]]; then
        src="$ROOT/lib/macos/lib/$base"
    else
        # Resolve symlink-style names (libFoo.N.dylib → real file via otool path)
        cand="$(find "$LIB_SRC" "$ROOT/lib/macos/lib" -name "$base" 2>/dev/null | head -1 || true)"
        [[ -n "$cand" ]] && src="$cand"
    fi
    if [[ -n "$src" && -f "$src" ]]; then
        cp -f "$src" "$FRAMEWORKS/$base"
    else
        echo "warning: missing dylib for $base" >&2
    fi
done < <(otool -L "$EXE" | awk '/@rpath\//{ gsub(/:.*/, "", $1); sub(/^@rpath\//, "", $1); print $1 }' | sort -u)

# Also pull common transitive libs that show up only on the first-level deps.
for more in libbrotlidec.1.1.0.dylib libbrotlicommon.1.1.0.dylib libbz2.1.0.8.dylib \
            libicudata.74.2.dylib libvorbis.0.4.9.dylib; do
    if [[ ! -f "$FRAMEWORKS/$more" ]]; then
        if [[ -f "$LIB_SRC/$more" ]]; then
            cp -f "$LIB_SRC/$more" "$FRAMEWORKS/$more"
        elif [[ -f "$ROOT/lib/macos/lib/$more" ]]; then
            cp -f "$ROOT/lib/macos/lib/$more" "$FRAMEWORKS/$more"
        fi
    fi
done

# Drop absolute install rpath; load Frameworks via @executable_path.
OLD_RPATH="$(otool -l "$EXE" | awk '/LC_RPATH/{getline; getline; if ($1=="path") print $2;}' | head -1 || true)"
if [[ -n "$OLD_RPATH" ]]; then
    install_name_tool -delete_rpath "$OLD_RPATH" "$EXE" 2>/dev/null || true
fi
if ! otool -l "$EXE" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$EXE"
fi

# Ad-hoc sign so Finder / Gatekeeper can launch a local research build.
codesign --force --deep -s - "$APP" >/dev/null

test -x "$APP/Contents/MacOS/$EXE_NAME"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
test -f "$APP/Contents/Resources/g2.dat"

printf 'Packaged %s\n' "$APP"
printf '  tip: %s\n' "$SHORT_SHA"
printf '  open: open %q\n' "$APP"

write_portable_zip "$APP" "$ZIP_PATH"
