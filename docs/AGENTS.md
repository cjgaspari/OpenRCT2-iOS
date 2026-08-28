# AGENTS.md — OpenRCT2 Touch

> Operating manual for AI coding agents working on this repo. Read this fully before making changes.
> This is your **working memory**; [`openrct2-ipados-BUILD-PLAN.md`](openrct2-ipados-BUILD-PLAN.md) is the full reference manual. When in doubt, defer to that plan.

---

## Mission

Port **OpenRCT2** to run **natively on iPhone and iPad** with finger and hardware-pointer controls. This repo is the fork **`chrissotraidis/OpenRCT2Touch`** (forked from `OpenRCT2/OpenRCT2`, GPLv3). Apple Pencil and multiplayer are outside the current release scope. The live presentation contract is portrait and landscape on both device families.

**Success = the MVP demo:** on a physical iPad, the app launches natively, loads user-imported RCT2 data, and lets you build a coaster + place scenery with fingers or an attached pointer at a playable frame rate — plus one community plugin or custom scenario loading on-device.

---

## Golden rules (NON-NEGOTIABLE)

1. **Assets are sacred.** Never commit, push, or put the `ref/` folder or any RollerCoaster Tycoon game data into git, an IPA, or an xcarchive. `ref/` is git-ignored; it is the user's own copy. A local Simulator `.app` under `build/` may include that ignored payload for personal installs. If a change would put game assets into a tracked file, a commit, or a distributable archive → **STOP, that is a hard error.**
2. **Branch discipline.** Do all work on the **`ipad`** branch (or short-lived phase branches merged into it). **Never commit to `develop`** — it is the read-only mirror of upstream. **Never push to `upstream` / `OpenRCT2/OpenRCT2`. Never open a pull request against upstream.** This is a standalone fork.
3. **Preserve provenance.** Keep every upstream `licence.txt`, per-file copyright header, and `contributors.md` intact. Never strip or rewrite them. Never rewrite `develop` history; no force-pushes to shared branches. Keep the "forked from" link.
4. **Commit hygiene.** Small, reversible commits, each with a green build. Prefix port commits `[touch] …` (e.g. `[touch] Phase 3: add UiContext.iOS.mm`). State what changed. **Never leave `ipad` red.**
5. **macOS-headless-first.** Prove every change you can in the fast macOS inner loop before touching iOS. iOS is the outer loop.
6. **Attribution.** `README-touch.md` credits OpenRCT2 and states this is an unofficial, unaffiliated community port. Keep it that way.
7. **Sync deliberately.** To take upstream changes: update `develop` from `upstream`, then rebase/merge `ipad` onto a chosen pinned commit — never blind-merge a moving target mid-phase.
8. **Stop and ask at the human gates** (below).

## Human gates — STOP and ask the human

- First device provisioning / code-signing trust.
- Any "does this *feel* right?" judgment for touch UX (Phase 7).
- Dependency-build dead ends (Phase 2) after a few failed attempts — don't thrash.
- Anything that would move `ref/`/game assets into a commit, IPA, or xcarchive (should never happen).

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
./scripts/run-ios-sim.sh verify all   # iPhone and iPad lifecycle + screenshot (portrait or landscape)
```
UI rendering, asset-import plumbing, input wiring. Use `iphone` or `ipad` instead of `all` for a single family.

**Outer loop — physical iPhone or iPad (needs the human for setup + feel):**
```bash
./scripts/play-ios-device.sh      # signed install + launch; prefers a connected iPhone Air
./scripts/collect-crash.sh        # pulls matching crash reports via CoreDevice
```

Team and UDID live in gitignored `runtime/device.env` (copy `scripts/device.env.example`). Unlock the device before launch.

If a script doesn't exist yet, creating it is part of the current phase (see the [master plan §9](openrct2-ipados-BUILD-PLAN.md#9-the-automation-harness)).

---

## Where things live (the map)

Paths are relative to the repo root. Full detail is in the [master plan §6](openrct2-ipados-BUILD-PLAN.md#6-upstream-architecture-youre-grafting-onto).

- **Filesystem resolver:** `src/openrct2/PlatformEnvironment.cpp` / `.h` — seven roots (`DirBase`); everything the engine reads/writes goes through here.
- **Per-OS platform layer:** `src/openrct2/platform/` — add **`Platform.iOS.mm`** beside `Platform.macOS.mm` (sandbox/bundle path resolution).
- **UI / SDL context:** `src/openrct2-ui/` — add **`UiContext.iOS.mm`** beside `UiContext.macOS.mm`; touch and GameController input goes in `src/openrct2-ui/input/`; the OpenGL renderer to disable is in `drawing/`.
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

**Phase 6 — Input I: pointer, keyboard, mouse.**
**Goal:** fully playable with a Magic Keyboard/trackpad or mouse—the quickest "it plays like the PC" milestone.
**Exit criteria:** on a real iPad with keyboard/trackpad or mouse, play a scenario end-to-end: build a coaster, place scenery, and use shortcuts.

The verified checkpoint and exact remaining device gate are recorded in
`docs/DEVELOPMENT-STATUS.md`.

> Update this section as you progress. Copy the next phase's Goal + Exit criteria from the [master plan §8](openrct2-ipados-BUILD-PLAN.md#8-the-phase-by-phase-engineering-plan). Keep a running "top device crashes" list here once on-device (Phase 9+).

## Phase ladder (from the master plan §8)

0. Repo & tooling bootstrap → 1. macOS-from-source baseline (keystone) → 2. iOS dependency toolchain (the pit) → 3. iOS app shell + SDL boots to title (Simulator) → 4. Software renderer → Metal surface → 5. Filesystem/sandbox + asset import → 6. Pointer/keyboard/mouse (playable fast) → 7. Touch controls → 8. Release documentation/package hygiene → 9. Performance/memory/stability → 10. Plugins, custom content, packaging.

Do not advance a phase until its Exit criteria are green.

## Dependency manifest

Record exact versions + build flags of every cross-compiled iOS dependency in `vendor/MANIFEST.md` as you build them (Phase 2), for reproducibility.
