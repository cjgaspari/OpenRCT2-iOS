#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

APP="${1:-}"
INSTALL_ROOT="${2:-}"
TRIPLET="${3:-}"

if [[ -z "$APP" || -z "$INSTALL_ROOT" || -z "$TRIPLET" ]]; then
    echo "Usage: $0 <app-bundle> <vcpkg-install-root> <triplet>" >&2
    exit 2
fi
if [[ ! -d "$APP" ]]; then
    echo "Missing app bundle: $APP" >&2
    exit 1
fi

"$ROOT/scripts/check-repo-safety.sh"

LICENCES="$APP/Licences"
THIRD_PARTY="$LICENCES/third-party"
mkdir -p "$THIRD_PARTY"

cp "$ROOT/licence.txt" "$LICENCES/GPL-3.0-or-later.txt"
cp "$ROOT/contributors.md" "$LICENCES/OpenRCT2-contributors.md"
cp "$ROOT/NOTICE.md" "$LICENCES/OpenRCT2-Touch-NOTICE.md"
cp "$ROOT/vendor/MANIFEST.md" "$LICENCES/iOS-dependency-manifest.md"

for dependency in sdl2 icu freetype libpng zlib zstd libzip nlohmann-json; do
    source_path="$INSTALL_ROOT/$TRIPLET/share/$dependency/copyright"
    if [[ ! -f "$source_path" ]]; then
        echo "Missing vcpkg licence text for $dependency: $source_path" >&2
        exit 1
    fi
    cp "$source_path" "$THIRD_PARTY/$dependency.txt"
done

find "$APP" -name .DS_Store -delete

echo "Staged GPL, attribution, and third-party notices in $LICENCES"
