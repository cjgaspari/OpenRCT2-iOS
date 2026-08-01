#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

APP="${1:-$ROOT/build/ios-libs-ios-arm64/OpenRCT2Touch.app}"
SHORT_COMMIT="$(git -C "$ROOT" rev-parse --short=12 HEAD)"
IPA="${2:-$ROOT/build/packages/OpenRCT2Touch-$SHORT_COMMIT-unsigned.ipa}"

if [[ ! -d "$APP" ]]; then
    echo "Missing iOS device app bundle: $APP" >&2
    echo "Build it first with: ./scripts/build-ios.sh device" >&2
    exit 1
fi
if [[ "$IPA" != *.ipa ]]; then
    echo "Output path must end in .ipa: $IPA" >&2
    exit 2
fi
if [[ -e "$IPA" ]]; then
    echo "Refusing to overwrite existing IPA: $IPA" >&2
    exit 1
fi
if [[ -d "$APP/_CodeSignature" || -f "$APP/embedded.mobileprovision" ]]; then
    echo "Refusing to label a signed or provisioned app as an unsigned IPA." >&2
    exit 1
fi

"$ROOT/scripts/check-repo-safety.sh"
"$ROOT/scripts/verify-ios-bundle.sh" "$APP" IOS

mkdir -p "$(dirname "$IPA")"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/openrct2touch-ipa.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

mkdir -p "$TEMP_ROOT/Payload"
ditto --norsrc --noextattr "$APP" "$TEMP_ROOT/Payload/OpenRCT2Touch.app"
(
    cd "$TEMP_ROOT"
    COPYFILE_DISABLE=1 /usr/bin/zip -qry "$TEMP_ROOT/OpenRCT2Touch.ipa" Payload
)

unzip -tq "$TEMP_ROOT/OpenRCT2Touch.ipa" >/dev/null
IPA_CONTENTS="$(unzip -Z1 "$TEMP_ROOT/OpenRCT2Touch.ipa")"
if ! grep -Fx 'Payload/OpenRCT2Touch.app/OpenRCT2Touch' <<< "$IPA_CONTENTS" >/dev/null; then
    echo "IPA is missing the OpenRCT2 Touch executable." >&2
    exit 1
fi

FORBIDDEN_MATCHES="$(
    grep -Ei '(^|/)(g1\.dat|css1\.dat|css2\.dat|rct2\.exe)$|/(ObjData|Scenarios|Tracks)/|\.(sv4|sv6|sc4|sc6|td4|td6)$|(^|/)(_CodeSignature|embedded\.mobileprovision)(/|$)' \
        <<< "$IPA_CONTENTS" || true
)"
if [[ -n "$FORBIDDEN_MATCHES" ]]; then
    echo "Forbidden game data or signing material found in IPA:" >&2
    echo "$FORBIDDEN_MATCHES" >&2
    exit 1
fi

mv "$TEMP_ROOT/OpenRCT2Touch.ipa" "$IPA"
echo "Unsigned ROM-free IPA passed: $IPA"
shasum -a 256 "$IPA"
