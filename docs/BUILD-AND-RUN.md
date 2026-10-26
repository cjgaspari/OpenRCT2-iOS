# Build and run on your iPhone or iPad

Short guide for running OpenRCT2 Touch on your own hardware after you change code.

## What you need once

1. A Mac with Xcode installed.
2. Your Apple developer team id (from **Xcode → Settings → Accounts**, or `security find-identity -v -p codesigning`).
3. Your own RCT2 game files in `ref/rct2/` (gitignored; never commit them).
4. An iPhone or iPad connected by USB or on the same network, unlocked, and trusted on the Mac.

## One-time setup

```sh
mkdir -p runtime
cp scripts/device.env.example runtime/device.env
```

Open `runtime/device.env` and set:

```sh
OPENRCT2_DEVELOPMENT_TEAM=YOUR_TEAM_ID_HERE
```

That file stays on your machine only. Do not commit it.

## The normal loop after you edit code

From the repo root:

```sh
./scripts/play-ios-device.sh
```

That one command:

1. Builds a signed iOS app.
2. Copies your local `ref/rct2` into this personal development app bundle.
3. Installs on a connected device.
4. Launches OpenRCT2 Touch.

By default it prefers **CJ's iPhone Duo**. Use a flag when you want a different target:

| Command | What it does |
| --- | --- |
| `./scripts/play-ios-device.sh` | iPhone Duo first, then iPhone Air, any iPhone, then any iPad |
| `./scripts/play-ios-device.sh --duo` | Require a connected iPhone Duo; do not fall back |
| `./scripts/play-ios-device.sh --iphone` | iPhone only (Duo, then Air, preferred) |
| `./scripts/play-ios-device.sh --ipad` | iPad only (iPad Pro preferred) |
| `./scripts/play-ios-device.sh --all` | Build once, install on every connected device |
| `./scripts/play-ios-device.sh --list` | Show connected device names and UDIDs |
| `./scripts/play-ios-device.sh --console` | Stream launch logs until the app exits |

For a one-command Duo-only shortcut, run `./scripts/play-ios-duo.sh`. It requires
CJ's iPhone Duo and never falls back to another connected iPhone. Pass
`--console` when you also want streamed device logs.

Pin a specific device in `runtime/device.env`:

```sh
OPENRCT2_DEVICE_UDID=00008140-...
```

That pin is used when you run `./scripts/play-ios-device.sh` with no target flag. Passing `--duo`, `--iphone`, `--ipad`, or `--all` overrides the pin for that run.

Or pick by family without a UDID:

```sh
OPENRCT2_DEVICE_TARGET=ipad
```

## Faster checks before a real device

Use these when you are not testing signing, install, or touch feel:

```sh
# Engine logic (seconds)
./scripts/build-macos.sh
./scripts/run-macos-headless.sh

# UI in Simulator (minutes)
./scripts/build-ios.sh sim
./scripts/run-ios-sim.sh verify all
```

Device builds are the slow outer loop. Use them when Simulator is not enough.

## If something goes wrong

- **"Missing OPENRCT2_DEVELOPMENT_TEAM"** — fill in `runtime/device.env`.
- **"No connected physical iPhone or iPad"** — unlock the device, trust the Mac, replug USB or stay on the same Wi‑Fi, then run `--list`.
- **Locked / FBSOpenApplicationErrorDomain** — unlock the device and run the same command again.
- **Missing `ref/rct2/Data/g1.dat`** — copy your RCT2 install into `ref/rct2/`.
- **First device deps build is slow** — `./scripts/build-ios-deps.sh device` runs once; later installs reuse it.

Crash logs:

```sh
./scripts/collect-crash.sh
```

## Why not just open an Xcode project and press Run?

There **is** an Xcode project — CMake generates it under `build/ios-xcode-device/OpenRCT2.xcodeproj` when you build. It is not checked into git on purpose.

OpenRCT2 is a large C++ CMake project (hundreds of source files, vcpkg dependencies, feature flags, iOS toolchain settings). A hand-maintained `.xcodeproj` would:

- Drift from upstream OpenRCT2 every time engine files change.
- Duplicate dependency wiring that already lives in CMake and `vendor/`.
- Make it easy to accidentally ship proprietary RCT2 data or personal signing settings in git.

The scripts wrap the generated project so every run does the same safe steps: configure CMake, copy your ignored local data into the personal development app, sign with your local team, audit the bundle, then install with `devicectl`.

You *can* open the generated project in Xcode for debugging, but **Run** from Xcode alone will not copy `ref/rct2`, run bundle safety checks, or pick your connected device the same way every time. `./scripts/play-ios-device.sh` is the supported path.
