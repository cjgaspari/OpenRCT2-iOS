# AGENTS.md — OpenRCT2 Touch

> Operating manual for AI coding agents working on this repo. Read this fully before making changes.
> This is your **working memory**; `PLAN.md` is the full reference manual. When in doubt, defer to `PLAN.md`.

---

## Mission

Port **OpenRCT2** to run **natively on iPadOS** with touch + Apple Pencil controls. This repo is the fork **`chrissotraidis/OpenRCT2Touch`** (forked from `OpenRCT2/OpenRCT2`, GPLv3).

**Success = the MVP demo:** on a physical iPad, the app launches natively, loads user-imported RCT2 data, and lets you build a coaster + place scenery with touch and Apple Pencil at a playable frame rate — plus one community plugin or custom scenario loading on-device.

---

## Golden rules (NON-NEGOTIABLE)

1. **Assets are sacred.** Never commit, push, or package the `ref/` folder or any RollerCoaster Tycoon game data. `ref/` is git-ignored; it is the user's own copy, for local testing only. If a change would put game assets into a tracked file, a commit, or a distributable build → **STOP, that is a hard error.**
2. **Branch discipline.** Do all work on the **`ipad`** branch (or short-lived phase branches merged into it). **Never commit to `develop`** — it is the read-only mirror of upstream. **Never push to `upstream` / `OpenRCT2/OpenRCT2`. Never open a pull request against upstream.** This is a standalone fork.
3. **Preserve provenance.** Keep every upstream `licence.txt`, per-file copyright header, and `contributors.md` intact. Never strip or rewrite them. Never rewrite `develop` history; no force-pushes to shared branches. Keep the "forked from" link.
4. **Commit hygiene.** Small, reversible commits, each with a green build. Prefix port commits `[touch] …` (e.g. `[touch] Phase 3: add UiContext.iOS.mm`). State what changed. **Never leave `ipad` red.**
5. **macOS-headless-first.** Prove every change you can in the fast macOS inner loop before touching iOS. iOS is the outer loop.
6. **Attribution.** `README-touch.md` credits OpenRCT2 and states this is an unofficial, unaffiliated community port. Keep it that way.
7. **Sync deliberately.** To take upstream changes: update `develop` from `upstream`, then rebase/merge `ipad` onto a chosen pinned commit — never blind-merge a moving target mid-phase.
8. **Stop and ask at the human gates** (below).

## Human gates — STOP and ask the human

- First device provisioning / code-signing trust.
- Any "does this *feel* right?" judgment (touch/Pencil UX — Phases 7–8).
- Dependency-build dead ends (Phase 2) after a few failed attempts — don't thrash.
- Anything that would move `ref/`/game assets into a commit or a distributable artifact (should never happen).

---

## How to build & test

Three loops, fastest first. Every change ends in a command that returns pass/fail.

**Inner loop — macOS headless (unattended, seconds):**
```bash
./scripts/build-macos.sh
./scripts/run-macos-headless.sh   # builds a park, simulates, greps logs, screenshot-diffs → exit code
```
Use this for anything that isn't iOS-specific. If it's red, fix before moving on.

**Middle loop — iOS Simulator (mostly unattended):**
```bash
./scripts/build-ios.sh sim
# boots the Simulator, installs, launches with --console
```
UI rendering, asset-import plumbing, input wiring.

**Outer loop — physical iPad (needs the human for setup + feel):**
```bash
./scripts/build-ios.sh device
./scripts/install-run-ios.sh      # devicectl (iOS 17+) / ios-deploy (≤16), streams logs
./scripts/collect-crash.sh        # pulls crash reports via idevicecrashreport
```

If a script doesn't exist yet, creating it is part of the current phase (see `PLAN.md` §9).

---

## Where things live (the map)

Paths are relative to the repo root. Full detail in `PLAN.md` §6.

- **Filesystem resolver:** `src/openrct2/PlatformEnvironment.cpp` / `.h` — seven roots (`DirBase`); everything the engine reads/writes goes through here.
- **Per-OS platform layer:** `src/openrct2/platform/` — add **`Platform.iOS.mm`** beside `Platform.macOS.mm` (sandbox/bundle path resolution).
- **UI / SDL context:** `src/openrct2-ui/` — add **`UiContext.iOS.mm`** beside `UiContext.macOS.mm`; touch/Pencil/GameController input goes in `src/openrct2-ui/input/`; the OpenGL renderer to disable is in `drawing/`.
- **CLI / run modes:** `src/openrct2/command_line/RootCommands.cpp` — flags `--rct2-data-path`, `--openrct2-data-path`, `--user-data-path`, `--headless`, and subcommands `simulate`, `screenshot`, `set-rct2`.
- **Scripting (plugins):** `src/openrct2/scripting/` + `src/thirdparty/quickjs-ng/` — a no-JIT interpreter; runs fine on iOS, no special entitlement.
- **Mobile blueprint:** `src/openrct2-android/` — the SDL-owns-the-window pattern to imitate (reference only; don't modify for iOS).
- **Your additions:** `ios/App/*` (UIKit shell + Xcode project), `ios/toolchain/`, `ios/cmake/`, `scripts/`, `vendor/` (iOS deps, git-ignored), `ref/` (game data, git-ignored), `assets/engine/`, `runtime/`, `testdata/`, `build/`.

---

## Key facts (so you don't re-derive them)

- Engine: C++20, CMake, SDL2 (SDL3 migration open upstream — **stay on SDL2**).
- iOS rendering: use the **software renderer** (`DISABLE_OPENGL=ON`); the GL path is desktop GL 3.3-core and won't run on iOS.
- Plugins: quickjs-ng is a **bytecode interpreter, no JIT** — iOS's JIT restrictions do not apply. Keep `ENABLE_SCRIPTING=ON`.
- Data paths are override-driven — point them into the repo (`ref/rct2`, `assets/engine`, `runtime/user`) for reproducible runs.
- iOS sandbox: RCT2 data is imported via the Files app / document picker into the app sandbox; `ref/` is the developer stand-in for that during testing.

---

## Current phase

**Phase 3 — iOS app shell + SDL boots to title (Simulator).**
**Goal:** run the engine under a UIKit app and reach either the title screen or a clean missing-data/import state in an iPad Simulator.
**Exit criteria:** the UIKit/SDL entry point links and launches in an iPad Simulator; logs are streamable; background/foreground lifecycle transitions do not crash; the app bundle contains only redistributable engine assets.

> Update this section as you progress. Copy the next phase's Goal + Exit criteria from `PLAN.md` §8. Keep a running "top device crashes" list here once on-device (Phase 9+).

## Phase ladder (from `PLAN.md` §8)

0. Repo & tooling bootstrap → 1. macOS-from-source baseline (keystone) → 2. iOS dependency toolchain (the pit) → 3. iOS app shell + SDL boots to title (Simulator) → 4. Software renderer → Metal surface → 5. Filesystem/sandbox + asset import → 6. Pointer/keyboard/mouse (playable fast) → 7. Touch controls → 8. Apple Pencil → 9. Performance/memory/stability → 10. Plugins, custom content, packaging.

Do not advance a phase until its Exit criteria are green.

## Dependency manifest

Record exact versions + build flags of every cross-compiled iOS dependency in `vendor/MANIFEST.md` as you build them (Phase 2), for reproducibility.
