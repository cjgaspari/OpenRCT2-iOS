# OpenRCT2 Touch development status

- **Last updated:** July 14, 2026
- **Working branch:** `ipad`
- **Current goal:** [Goal 5 — Sandbox paths and user-owned data import](../GOAL-LOOP.md#goal-5--sandbox-paths-and-user-owned-data-import)
- **Code checkpoint:** `10035e9ce1` (`[touch] Phase 5: import RCT Classic data`)

The implementation has completed Goals 0–4. Goal 5 is complete in the iPad
Simulator and ready for a signed device run, but remains open until the manual
Files import succeeds on a physical iPad. The project must not advance to Goal
6 before that device gate is green.

## Goal ledger

| Goal | State | Evidence or remaining gate |
| --- | --- | --- |
| [0 — Safe workspace](../GOAL-LOOP.md#goal-0--safe-reproducible-workspace) | Complete | `ipad` is isolated from the read-only upstream mirror; repository safety checks and ignored `ref/` handling are in place. |
| [1 — macOS keystone](../GOAL-LOOP.md#goal-1--macos-keystone) | Complete | Native arm64 build and deterministic headless simulation pass with repo-local paths. |
| [2 — iOS build contract](../GOAL-LOOP.md#goal-2--ios-build-contract-and-dependency-closure) | Complete | Device and Simulator dependency slices link; versions, hashes, flags, and licences are recorded in [`vendor/MANIFEST.md`](../vendor/MANIFEST.md). |
| [3 — Simulator app boot](../GOAL-LOOP.md#goal-3--simulator-app-boot) | Complete | The UIKit/SDL application launches, streams logs, and reaches the OpenRCT2 UI in an iPad Simulator. |
| [4 — Framebuffer presentation](../GOAL-LOOP.md#goal-4--correct-software-framebuffer-presentation) | Complete | The software framebuffer presents through SDL's iOS Metal renderer in landscape at Retina scale. |
| [5 — Sandbox and import](../GOAL-LOOP.md#goal-5--sandbox-paths-and-user-owned-data-import) | **Device gate** | Sandbox paths persist; valid RCT2 and RCT Classic folders import from Files in the Simulator; malformed folders fail safely; a real scenario loads through the developer flow; the signing/install harness is ready. A manual import and scenario load on a physical iPad are still required. |
| [6 — Pointer, keyboard, mouse](../GOAL-LOOP.md#goal-6--pointer-keyboard-and-mouse-play) | Not started | Begins only after Goal 5's physical-device gate. |
| [7 — Finger-first controls](../GOAL-LOOP.md#goal-7--finger-first-controls) | Not started | Requires device interaction and human feel acceptance. |
| [8 — Apple Pencil](../GOAL-LOOP.md#goal-8--apple-pencil-differentiation) | Not started | Requires Pencil hardware and human feel acceptance. |
| [9 — Performance and stability](../GOAL-LOOP.md#goal-9--device-performance-and-stability) | Not started | Requires repeatable physical-device profiling and stress testing. |
| [10 — Content and installable MVP](../GOAL-LOOP.md#goal-10--plugincustom-content-and-installable-mvp) | Not started | Requires on-device plugin/custom-content proof, packaging audit, and the full MVP demo. |

## Current proof

- `./scripts/build-ios.sh all` builds and audits both iOS device and Simulator
  application bundles.
- `OPENRCT2_SKIP_MACOS_BUILD=1 ./scripts/build-ios-device.sh unsigned` produces
  an Xcode device build without requiring repository-held signing identity data.
- The Simulator Files picker successfully imports both the standard
  `Data/g1.dat` layout and RCT Classic's `Assets/g1.dat` layout. It preserves
  the source, persists the destination, repairs the stored path after app
  updates, and leaves no temporary or backup debris.
- A malformed folder is rejected with a useful error and no partial import.
- The local developer flow loads a real scenario. Proprietary game data remains
  outside tracked files and distributable bundles.
- The macOS headless loop completed 1,000 ticks with checksum
  `25232284e49cf2cb000000000000000000000000`.

## Immediate human gate

Connect, unlock, and trust the target iPad; enable Developer Mode; then use the
Apple development team and device identifiers reported by Xcode and
`xcrun devicectl`:

```bash
OPENRCT2_DEVELOPMENT_TEAM=<team> \
OPENRCT2_DEVICE_UDID=<device> \
    ./scripts/build-ios-device.sh signed
OPENRCT2_DEVICE_UDID=<device> ./scripts/install-run-ios.sh
```

On the iPad, choose a user-owned RCT2 or RCT Classic folder in Files, let the
import finish, relaunch once to prove persistence, and load a scenario. Record
the device model, iPadOS version, build commit, result, and any logs. Team and
device identifiers remain local and must not be committed.

## Remaining goal loop

After Goal 5's device proof, execute one goal at a time using the loop in
[`GOAL-LOOP.md`](../GOAL-LOOP.md#the-loop) and the engineering detail in the
master plan's [phase ladder](openrct2-ipados-BUILD-PLAN.md#8-the-phase-by-phase-engineering-plan):

1. **Finish Goal 5:** sign, install, import from Files, relaunch, and load a
   scenario on a physical iPad without proprietary data entering an app bundle
   or archive.
2. **Goal 6:** make a scenario playable end-to-end with a trackpad or mouse and
   keyboard, including left/right/middle click, scroll, text, and shortcuts.
3. **Goal 7:** make the same MVP flow usable with fingers through pan, zoom,
   long-press, placement confirmation, and touch-sized window controls.
4. **Goal 8:** distinguish Pencil from finger input and prove precise placement,
   terrain pressure/tilt, a bounded drawing prototype, and supported hover.
5. **Goal 9:** sustain at least 30 fps on the agreed mid-size park and complete a
   30-minute stress run without an out-of-memory failure; fix the top three
   reproducible device crashes.
6. **Goal 10:** load one plugin or custom scenario, audit the distributable for
   proprietary assets, install through the chosen private channel, and pass the
   complete physical-iPad MVP demo.

Every goal closes only when its exit proof in [`GOAL-LOOP.md`](../GOAL-LOOP.md#goal-ladder-and-exit-proofs)
is green. Physical signing, touch/Pencil feel, and any asset-packaging risk stay
explicit human gates.
