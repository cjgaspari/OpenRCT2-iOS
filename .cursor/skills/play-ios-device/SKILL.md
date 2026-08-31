---
name: play-ios-device
description: Build, sign, install, and launch OpenRCT2 Touch on a connected iPhone or iPad. Use when the user asks to run on device, install on CJ's iPhone Air, CJ's iPad Pro, play on the phone or tablet, or do a signed iOS device build.
---

# Play on a physical iPhone or iPad

```sh
./scripts/play-ios-device.sh           # default: prefers CJ's iPhone Air
./scripts/play-ios-device.sh --ipad  # prefers CJ's iPad Pro
./scripts/play-ios-device.sh --all   # build once, install on every connected device
./scripts/play-ios-device.sh --list  # show names and UDIDs
```

Signs a device build, bundles ignored `ref/rct2`, installs, and launches.

## Setup (once per machine)

```sh
mkdir -p runtime
cp scripts/device.env.example runtime/device.env
```

Set `OPENRCT2_DEVELOPMENT_TEAM` in `runtime/device.env`. Optionally pin `OPENRCT2_DEVICE_UDID` or set `OPENRCT2_DEVICE_TARGET` (`auto`, `iphone`, `ipad`, `all`). `runtime/` is gitignored; never commit team or UDID.

Human guide: `docs/BUILD-AND-RUN.md`.

## Rules

- Unlock the device before launch. A `Locked` / `FBSOpenApplicationErrorDomain` error means unlock and rerun the same command.
- Ignore the unavailable twin iPhone Air UDID if both appear in `devicectl`.
- `play-ios-device.sh` sets `OPENRCT2_BUNDLE_LOCAL_RCT2=ON`. Bare `build-ios-device.sh` defaults that flag **OFF** and deletes the previous `.app`.
- Do not use Xcode MCP install/run for this app; the CMake signed device bundle plus RCT2 copy lives in these scripts.
- Pass `--console` only when streamed device logs are needed. Default launch detaches.
- Never put proprietary RCT2 data, team IDs, or UDIDs in git, an IPA, or an xcarchive.
