#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/scripts/env.sh"

install_missing=false
if [[ "${1:-}" == "--install" ]]; then
    install_missing=true
elif [[ "$#" -ne 0 ]]; then
    printf 'Usage: %s [--install]\n' "$0" >&2
    exit 2
fi

required_commands=(git cmake ninja pkg-config xcodebuild xcrun)
missing_commands=()
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_commands+=("$command_name")
    fi
done

if [[ "${#missing_commands[@]}" -ne 0 && "$install_missing" == true ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        printf 'ERROR: Homebrew is required to install: %s\n' "${missing_commands[*]}" >&2
        exit 1
    fi
    packages=()
    for command_name in "${missing_commands[@]}"; do
        case "$command_name" in
            cmake|ninja|pkg-config) packages+=("$command_name") ;;
        esac
    done
    if [[ "${#packages[@]}" -ne 0 ]]; then
        brew install "${packages[@]}"
    fi
    exec "$0"
fi

if [[ "${#missing_commands[@]}" -ne 0 ]]; then
    printf 'ERROR: missing commands: %s\n' "${missing_commands[*]}" >&2
    printf 'Run %s --install to install supported Homebrew tools.\n' "$0" >&2
    exit 1
fi

cmake_version="$(cmake --version | awk 'NR == 1 { print $3 }')"
if [[ "$(printf '3.24\n%s\n' "$cmake_version" | sort -V | head -n 1)" != "3.24" ]]; then
    printf 'ERROR: CMake 3.24 or newer is required; found %s.\n' "$cmake_version" >&2
    exit 1
fi

xcode_version="$(xcodebuild -version | awk 'NR == 1 { print $2 }')"
ios_sdk="$(xcrun --sdk iphoneos --show-sdk-version)"
sim_sdk="$(xcrun --sdk iphonesimulator --show-sdk-version)"

mkdir -p "$USER_DATA" "$CACHE_DATA" "$OPENRCT2_DATA" "$BUILD_ROOT"

"$ROOT/scripts/check-repo-safety.sh"

if [[ ! -f "$RCT2_DATA/Data/g1.dat" ]]; then
    printf 'ERROR: no local RCT2 data found at %s/Data/g1.dat\n' "$RCT2_DATA" >&2
    exit 1
fi
if [[ ! -f "$SMOKE_PARK" ]]; then
    printf 'ERROR: tracked smoke park is missing: %s\n' "$SMOKE_PARK" >&2
    exit 1
fi

printf 'Bootstrap passed.\n'
printf '  branch: %s\n' "$(git branch --show-current)"
printf '  cmake: %s\n' "$cmake_version"
printf '  xcode: %s\n' "$xcode_version"
printf '  iphoneos SDK: %s\n' "$ios_sdk"
printf '  iphonesimulator SDK: %s\n' "$sim_sdk"
printf '  RCT2 data: local and ignored\n'
printf '  smoke park: tracked test fixture\n'
