#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

APP="${1:-}"
PLATFORM="${2:-}"

if [[ -z "$APP" || ! -d "$APP" || ( "$PLATFORM" != "IOS" && "$PLATFORM" != "IOSSIMULATOR" ) ]]; then
    echo "Usage: $0 <OpenRCT2Touch.app> <IOS|IOSSIMULATOR>" >&2
    exit 2
fi

"$ROOT/scripts/check-repo-safety.sh"

BINARY="$APP/OpenRCT2Touch"
plutil -lint "$APP/Info.plist"
if [[ "$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")" != "org.openrct2.touch" ]]; then
    echo "Unexpected iOS bundle identifier." >&2
    exit 1
fi

for required_asset in g2.dat fonts.dat palettes.dat tracks.dat language/en-GB.txt; do
    if [[ ! -f "$APP/$required_asset" ]]; then
        echo "App bundle is missing engine asset: $required_asset" >&2
        exit 1
    fi
done

if [[ "$(plutil -extract 'CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName' raw "$APP/Info.plist")" != "AppIcon" ]]; then
    echo "App bundle does not declare the compiled AppIcon catalog." >&2
    exit 1
fi

for icon_spec in "AppIcon60x60@2x.png:120" "AppIcon76x76@2x~ipad.png:152"; do
    IFS=: read -r icon_name expected_size <<< "$icon_spec"
    icon_path="$APP/$icon_name"
    if [[ ! -f "$icon_path" ]]; then
        echo "App bundle is missing compiled icon: $icon_name" >&2
        exit 1
    fi
    if [[ "$(sips -g pixelWidth "$icon_path" | awk '/pixelWidth:/ { print $2 }')" != "$expected_size"
        || "$(sips -g pixelHeight "$icon_path" | awk '/pixelHeight:/ { print $2 }')" != "$expected_size"
        || "$(sips -g hasAlpha "$icon_path" | awk '/hasAlpha:/ { print $2 }')" != "no" ]]; then
        echo "Compiled icon has unexpected dimensions or transparency: $icon_name" >&2
        exit 1
    fi
done

if [[ ! -f "$APP/Assets.car" ]]; then
    echo "App bundle is missing the compiled asset catalog." >&2
    exit 1
fi
ASSET_CATALOG_INFO="$(xcrun assetutil --info "$APP/Assets.car")"
if [[ "$(printf '%s' "$ASSET_CATALOG_INFO" | plutil -extract 1.Name raw -)" != "AppIcon"
    || "$(printf '%s' "$ASSET_CATALOG_INFO" | plutil -extract 1.AssetType raw -)" != "Icon Image"
    || "$(printf '%s' "$ASSET_CATALOG_INFO" | plutil -extract 1.Opaque raw -)" != "true"
    || "$(printf '%s' "$ASSET_CATALOG_INFO" | plutil -extract 1.PixelWidth raw -)" != "1024"
    || "$(printf '%s' "$ASSET_CATALOG_INFO" | plutil -extract 1.PixelHeight raw -)" != "1024" ]]; then
    echo "Compiled asset catalog does not contain the expected opaque 1024px AppIcon rendition." >&2
    exit 1
fi

PROPRIETARY_MATCHES="$(
    find "$APP" -type f -print \
        | rg -i '(^|/)(g1\.dat|css1\.dat|css2\.dat|rct2\.exe)$|/(ObjData|Scenarios)/|\.(sv4|sv6|sc4|sc6|td4|td6)$' \
        || true
)"
if [[ -n "$PROPRIETARY_MATCHES" ]]; then
    echo "Proprietary game-data signature found in app bundle:" >&2
    echo "$PROPRIETARY_MATCHES" >&2
    exit 1
fi

UNEXPECTED_LINKS="$(find "$APP" -type l -print)"
if [[ -n "$UNEXPECTED_LINKS" ]]; then
    echo "Unexpected symbolic link found in app bundle:" >&2
    echo "$UNEXPECTED_LINKS" >&2
    exit 1
fi

while IFS= read -r -d '' bundled_file; do
    relative_path="${bundled_file#"$APP"/}"
    case "$relative_path" in
        Info.plist|OpenRCT2Touch|embedded.mobileprovision|_CodeSignature/CodeResources|Assets.car|AppIcon60x60@2x.png|AppIcon76x76@2x~ipad.png)
            continue
            ;;
        PkgInfo)
            if ! cmp -s <(printf 'APPL????') "$bundled_file"; then
                echo "Unexpected iOS PkgInfo contents." >&2
                exit 1
            fi
            continue
            ;;
    esac

    engine_source="$ROOT/assets/engine/$relative_path"
    if [[ ! -f "$engine_source" ]]; then
        echo "App bundle contains a file outside the redistributable engine manifest: $relative_path" >&2
        exit 1
    fi
    if ! cmp -s "$engine_source" "$bundled_file"; then
        echo "Bundled engine asset differs from its redistributable source: $relative_path" >&2
        exit 1
    fi
done < <(find "$APP" -type f -print0)

file "$BINARY"
xcrun vtool -show-build "$BINARY"
if ! xcrun vtool -show-build "$BINARY" | rg "platform $PLATFORM" >/dev/null; then
    echo "App binary has the wrong Apple platform identity; expected $PLATFORM." >&2
    exit 1
fi

if [[ -d "$APP/_CodeSignature" ]]; then
    codesign --verify --deep --strict --verbose=2 "$APP"
fi

echo "iOS app bundle passed for $PLATFORM: $APP"
