# OpenRCT2 Touch

**A native iPadOS port of [OpenRCT2](https://github.com/OpenRCT2/OpenRCT2) — touch-first, with Apple Pencil support.**

> ⚠️ **Unofficial community project.** OpenRCT2 Touch is **not affiliated with, endorsed by, or supported by the OpenRCT2 team.** It is an independent fork that adapts their work to run natively on iPad. For the real, cross-platform OpenRCT2, go to **[openrct2.io](https://openrct2.io)** and **[OpenRCT2/OpenRCT2](https://github.com/OpenRCT2/OpenRCT2)**. Please do not send bug reports about this port to the upstream project.

> 🚧 **Status: pre-alpha / work in progress.** This is an active porting effort. It may not build or run yet. Nothing here is a finished product.

---

## What this is

OpenRCT2 Touch takes the open-source [OpenRCT2](https://github.com/OpenRCT2/OpenRCT2) engine — a from-scratch re-implementation of *RollerCoaster Tycoon 2* — and makes it run **natively on iPadOS** (real Apple-silicon app; not streaming, not a VM, not an emulator), with controls redesigned for **touch and Apple Pencil**.

The goal is to bring what the frozen commercial mobile version can't: **mods, JavaScript plugins, custom scenarios and parks, multiplayer, unlimited park size, and years of modern quality-of-life improvements** — on a tablet, with a Pencil.

This work is done as a **human-directed, AI-assisted port**. A coding agent does much of the mechanical porting under human direction and testing.

## What this is *not*

- Not the official OpenRCT2. (See the disclaimer above.)
- Not on the App Store, and not planned for it (OpenRCT2 is GPLv3; see [Licensing](#licensing)).
- Not a way to get *RollerCoaster Tycoon 2* for free. **You must own a legitimate copy** (see below).

## You must bring your own game data

Like OpenRCT2 itself, this is an **engine re-implementation** — it does **not** include any *RollerCoaster Tycoon* assets. To run it you need the original data files from a copy of **RollerCoaster Tycoon 2** (or **RollerCoaster Tycoon Classic**) that **you own** — from [GOG](https://www.gog.com/), [Steam](https://store.steampowered.com/), or an original CD. No game assets are distributed with this project, ever.

## Requirements

- A Mac with Apple Silicon + Xcode (to build).
- An iPad (M-series recommended for Apple Pencil hover and headroom).
- Your own RollerCoaster Tycoon 2 / RCT Classic data files.

## Building (early notes)

This is an active port; expect rough edges. High level (see `PLAN.md` for the full guide):

```bash
# 1. Clone your fork and switch to the working branch
git clone https://github.com/chrissotraidis/OpenRCT2Touch
cd OpenRCT2Touch
git checkout ipad

# 2. Install toolchain + dependencies, sanity-check the environment
./scripts/bootstrap.sh

# 3. Put YOUR RollerCoaster Tycoon 2 data where the build can find it (git-ignored)
#    (must contain Data/g1.dat)
#    -> ./ref/rct2/

# 4. Build & smoke-test on macOS first (the fast inner loop)
./scripts/build-macos.sh
./scripts/run-macos-headless.sh

# 5. iOS: build dependencies, build the app, install to a tethered iPad
./scripts/build-ios-deps.sh
./scripts/build-ios.sh
./scripts/install-run-ios.sh
```

## Licensing

OpenRCT2 Touch is a fork of OpenRCT2 and is licensed under the **GNU General Public License v3.0 (or later)**, the same as upstream. All upstream copyright notices, `licence.txt`, and `contributors.md` are preserved. New code added for this port is also GPLv3.

Because of the well-known conflict between GPLv3 and the Apple App Store terms (the VLC precedent), this project is **not distributed via the App Store**. It is built from source and/or sideloaded.

## Credits & thanks

Enormous thanks to the **[OpenRCT2](https://github.com/OpenRCT2/OpenRCT2) developers and contributors** — this project is only possible because of their years of work re-implementing the engine in the open. And to **Chris Sawyer**, creator of RollerCoaster Tycoon.

*RollerCoaster Tycoon* is a trademark of its respective owners. This project is not affiliated with or endorsed by them.
