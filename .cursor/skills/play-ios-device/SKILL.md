---
name: play-ios-device
description: Build, sign, install, and launch OpenRCT2 Touch on a connected iPhone or iPad. Use when the user asks to run on device, install on CJ's iPhone Air, play on the phone, or do a signed iOS device build.
---

# Play on a physical iPhone

```sh
./scripts/play-ios-device.sh
```

That is the whole command. It signs a device build, bundles ignored `ref/rct2`, installs on the connected phone (prefers CJ’s iPhone Air), and launches.

## Setup (once per machine)

```sh
mkdir -p runtime
cp scripts/device.env.example runtime/device.env
```

Set `OPENRCT2_DEVELOPMENT_TEAM` in `runtime/device.env`. Optionally pin `OPENRCT2_DEVICE_UDID`. `runtime/` is gitignored; never commit team or UDID.

## Rules

- Unlock the phone before launch. A `Locked` / `FBSOpenApplicationErrorDomain` error means unlock and rerun the same command.
- Ignore the unavailable twin iPhone Air UDID if both appear in `devicectl`.
- `play-ios-device.sh` sets `OPENRCT2_BUNDLE_LOCAL_RCT2=ON`. Bare `build-ios-device.sh` defaults that flag **OFF** and deletes the previous `.app`.
- Do not use Xcode MCP install/run for this app; the CMake signed device bundle plus RCT2 copy lives in these scripts.
- Pass `--console` only when streamed device logs are needed. Default launch detaches.
- Never put proprietary RCT2 data, team IDs, or UDIDs in git, an IPA, or an xcarchive.
