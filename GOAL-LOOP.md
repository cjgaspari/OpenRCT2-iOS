# OpenRCT2 Touch goal loop

## Goal to give the agent

Build the OpenRCT2 Touch MVP described in `docs/openrct2-ipados-BUILD-PLAN.md` on the `ipad` branch. Continue autonomously through the smallest verifiable engineering slice until the current goal's exit criteria are green. Preserve user-owned game data, upstream provenance, and a green macOS-first build. Stop only at an explicit human gate or when three materially different attempts have demonstrated the same external blocker.

The terminal outcome is a signed native iPhone and iPadOS build that imports the user's own RCT2 data, loads a scenario, can build a coaster and place scenery with pointer and finger controls at at least 30 fps on a mid-size park, and loads one plugin or custom scenario. Apple Pencil and multiplayer are explicitly outside this release scope. The live presentation contract is portrait and landscape on both device families.

## The loop

Repeat this sequence for one small slice at a time:

1. **Observe:** read `AGENTS.md`, this file, the current goal, `git status`, and the last failing proof.
2. **Protect:** confirm the branch is allowed and run `./scripts/check-repo-safety.sh` before any build, commit, staging, archive, or install operation.
3. **Choose:** select the smallest unmet exit criterion. Do not start work from a later goal.
4. **Define proof first:** write down the exact command and observable result that will prove the slice complete.
5. **Implement:** make one reversible change. Do not mix infrastructure, behavior, and polish unless the proof requires all three.
6. **Verify fast to slow:** static/safety checks, focused build or test, full macOS headless loop, Simulator, then device only when applicable.
7. **Diagnose:** on failure, preserve the error, form a new hypothesis, and make a materially different attempt. After three attempts at the same external blocker, stop at the human gate with evidence.
8. **Audit:** inspect the diff, licences, generated artifacts, and tracked files. Confirm no proprietary asset entered a tracked file or distributable bundle.
9. **Checkpoint:** when green, create one `[touch] ...` commit, record the proof, and update `AGENTS.md` if a goal was completed.
10. **Advance:** move to the next goal only when every current exit criterion is green.

Each iteration reports: current goal, slice, changed files, proof commands and outcomes, remaining risk, and the next slice or human gate.

## Goal ladder and exit proofs

### Goal 0 — Safe, reproducible workspace

- Work is on `ipad`; the already-published documentation commit on `develop` is preserved rather than rewritten.
- `ref/` data is ignored and `git ls-files ref` reports only `ref/README.md` or nothing.
- `upstream` has no usable push URL in the local clone.
- `./scripts/bootstrap.sh` and `./scripts/check-repo-safety.sh` exit 0.
- Root instructions, environment paths, and the initial `[touch]` commit exist.

### Goal 1 — macOS keystone

- `./scripts/build-macos.sh` builds native arm64 from a clean build directory.
- All runtime roots are repo-local.
- `./scripts/run-macos-headless.sh` loads a tracked, legally redistributable smoke park, simulates fixed ticks, rejects fatal/assert logs, and exits 0.
- A windowed run works with the user's local RCT2 data.

### Goal 2 — iOS build contract and dependency closure

- CMake distinguishes macOS from iOS instead of treating every `APPLE` target as Cocoa/macOS.
- The UI code can be linked into an iOS app target; do not assume the existing desktop `openrct2` executable is a `libopenrct2ui` library.
- Device arm64 and Simulator arm64 dependency smoke targets link successfully.
- Exact dependency sources, versions, hashes, flags, licences, and slices are recorded in `vendor/MANIFEST.md`.
- OpenGL, HTTP, networking, FLAC, and Vorbis start disabled; scripting stays enabled. Re-enable optional features deliberately later.

### Goal 3 — Simulator app boot

- The UIKit/SDL entry point links the engine and launches in an iPad Simulator.
- Logs are streamable and lifecycle transitions do not crash.
- The build contains only redistributable engine assets and shows either the title UI or a clean missing-data/import state.

### Goal 4 — Correct software-framebuffer presentation

- The engine software framebuffer is presented through SDL's iOS Metal renderer.
- Portrait and landscape, Retina drawable, scene-filling canvas (no safe-area letterbox), palette, aspect ratio, and resize/lifecycle behavior are correct. On iOS/iPadOS 27 the scene resizes fluidly, standard status and Home UI remain visible, and system edge gestures are not deferred.
- A repeatable Simulator screenshot check is green (iPhone portrait; iPad landscape on this host). The canvas resizes with the window; iPhone Simulator LCD often stays portrait while presentation logs still show a landscape framebuffer.

**Scope change:** the live contract is a universal canvas on iPhone and iPad in portrait and landscape. `window_scale` stays 1 (points). The park fills its current scene; interactive native chrome uses safe, corner-adapted margins. iPhone does not use upside-down; iPad allows all four orientations and fluid system window resizing.

### Goal 5 — Sandbox paths and user-owned data import

- Bundle resources are read-only; Documents/Library paths are writable and survive relaunch.
- The Files picker validates `Data/g1.dat`, copies or coordinates access safely, reports progress/errors, and persists the selected path.
- Proprietary data is never git-tracked or copied into `.ipa`, `.xcarchive`, or another distributable artifact. A local Simulator `.app` under `build/` may include ignored `ref/rct2` for personal installs; Documents seeding remains valid.
- A scenario loads through both a local developer flow and one manual Files import on a physical iPad.

### Goal 6 — Pointer, keyboard, and mouse play

- Existing SDL input is used where sufficient; GameController-specific glue is added only for uncovered behavior.
- Left/right/middle click, scroll, pointer movement, text entry, and shortcuts work on device.
- A coaster can be built and scenery placed end-to-end with a trackpad or mouse.

### Goal 7 — Finger-first controls

- Pinch zoom, one-finger map pan, long-press secondary action, tap/confirm placement, window manipulation, and usable hit targets pass focused tests.
- The human confirms the MVP can be completed with fingers and the interaction feels acceptable.

### Goal 8 — Release documentation and package hygiene

- The root README is the canonical install guide and matches the implemented
  build, signing, Files import, controls, and limitations.
- Apple Pencil and multiplayer are explicitly unsupported rather than promoted.
- The app bundle contains the GPL, attribution, dependency manifest, and
  third-party licence texts while rejecting proprietary game data.
- Fork-specific issue and contribution paths do not redirect iPad users to
  upstream support.

### Goal 9 — Device performance and stability

- At least 30 fps on the agreed mid-size park with recorded device/build/settings.
- A 30-minute stress session does not OOM.
- The top three reproducible device crashes are fixed and regression-covered where practical.

### Goal 10 — Plugin/custom content and installable MVP

- One JavaScript plugin or custom scenario loads on-device.
- Safety checks prove no proprietary assets are present in the archive/export.
- A signed build installs through the chosen private channel and the complete demo script passes on a physical iPad.

## Human gates

Stop and ask for the human only for:

- first device provisioning, signing, trust, or account selection;
- touch-control feel decisions;
- a dependency/toolchain blocker repeated across three materially different attempts;
- any operation that could place proprietary data in source control or a distributable artifact;
- a choice that materially changes scope, licensing, or distribution.

## Corrections incorporated from the repository audit

- The current fork began with the port documents committed on `develop`; do not rewrite that published history. Branch from it once, then keep new work on `ipad`.
- The local RCT2 install is under `ref/Rollercoaster Tycoon 2`, not `ref/rct2`; environment discovery supports both without moving user files.
- The root CMake build currently creates `libopenrct2` plus an `openrct2` UI executable. Goal 2 must establish an iOS-linkable UI target or an equivalent source target.
- Existing Apple guards and framework links mean macOS (`Cocoa`, `CoreServices`) and iOS (`UIKit`, mobile-safe APIs) must be separated explicitly.
- `Ui.cpp` exposes `SDL_main` only for Android today; the iOS entry-point contract must be proven rather than assumed.
- Proprietary data may be placed in an installed app sandbox or a local Simulator `.app` under `build/` for personal testing. Never stage it into git, an IPA, or an xcarchive.
