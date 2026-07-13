#!/usr/bin/env bash

# Source this file; do not execute it.
TOUCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT="${ROOT:-$TOUCH_ROOT}"

if [[ -z "${RCT2_DATA:-}" ]]; then
    if [[ -f "$ROOT/ref/rct2/Data/g1.dat" ]]; then
        RCT2_DATA="$ROOT/ref/rct2"
    elif [[ -f "$ROOT/ref/Rollercoaster Tycoon 2/Data/g1.dat" ]]; then
        RCT2_DATA="$ROOT/ref/Rollercoaster Tycoon 2"
    else
        RCT2_DATA="$ROOT/ref/rct2"
    fi
fi

export RCT2_DATA
export OPENRCT2_DATA="${OPENRCT2_DATA:-$ROOT/assets/engine}"
export USER_DATA="${USER_DATA:-$ROOT/runtime/user}"
export CACHE_DATA="${CACHE_DATA:-$ROOT/runtime/cache}"
export BUILD_ROOT="${BUILD_ROOT:-$ROOT/build}"
export MACOS_BUILD_DIR="${MACOS_BUILD_DIR:-$BUILD_ROOT/macos}"
export IOS_SIM_BUILD_DIR="${IOS_SIM_BUILD_DIR:-$BUILD_ROOT/ios-sim}"
export IOS_DEVICE_BUILD_DIR="${IOS_DEVICE_BUILD_DIR:-$BUILD_ROOT/ios-device}"
export SMOKE_PARK="${SMOKE_PARK:-$ROOT/test/tests/testdata/parks/tile-element-tests.sv6}"
export SMOKE_EXPECTED_CHECKSUM="${SMOKE_EXPECTED_CHECKSUM-25232284e49cf2cb000000000000000000000000}"
