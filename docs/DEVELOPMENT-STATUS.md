# OpenRCT2 Touch development status

- **Last updated:** July 14, 2026
- **Working branch:** `ipad`
- **Current goal:** [Goal 5 — Sandbox paths and user-owned data import](../GOAL-LOOP.md#goal-5--sandbox-paths-and-user-owned-data-import)
- **Code checkpoint:** `894a029a9d` (`[touch] Add finger-first iPad controls`)

The implementation has completed Goals 0–4. A signed build now runs on a
physical M2 iPad Pro, persists developer-seeded user-owned RCT2 data across
relaunches, loads a scenario, and has working pointer, keyboard, trackpad, and
finger controls. The human tester reports that the game appears stable and the
controls feel good at this checkpoint.

Goal 5 remains technically open because the physical-device data was seeded
directly into the installed app's Documents container. The equivalent manual
folder selection through the Files picker has passed in Simulator but has not
yet been recorded on the physical iPad. Goals 6 and 7 have useful on-device
progress, but their complete end-to-end exit scripts are also still pending.

## Goal ledger

| Goal | State | Evidence or remaining gate |
| --- | --- | --- |
| [0 — Safe workspace](../GOAL-LOOP.md#goal-0--safe-reproducible-workspace) | Complete | `ipad` is isolated from the read-only upstream mirror; repository safety checks and ignored `ref/` handling are in place. |
| [1 — macOS keystone](../GOAL-LOOP.md#goal-1--macos-keystone) | Complete | Native arm64 build and deterministic headless simulation pass with repo-local paths. |
| [2 — iOS build contract](../GOAL-LOOP.md#goal-2--ios-build-contract-and-dependency-closure) | Complete | Device and Simulator dependency slices link; versions, hashes, flags, and licences are recorded in [`vendor/MANIFEST.md`](../vendor/MANIFEST.md). |
| [3 — Simulator app boot](../GOAL-LOOP.md#goal-3--simulator-app-boot) | Complete | The UIKit/SDL application launches, streams logs, and reaches the OpenRCT2 UI in an iPad Simulator. |
| [4 — Framebuffer presentation](../GOAL-LOOP.md#goal-4--correct-software-framebuffer-presentation) | Complete | The software framebuffer presents through SDL's iOS Metal renderer in landscape at Retina scale. |
| [5 — Sandbox and import](../GOAL-LOOP.md#goal-5--sandbox-paths-and-user-owned-data-import) | **Device gate** | Sandbox paths persist and a scenario loads on a physical iPad using developer-seeded user-owned data. Standard RCT2 and RCT Classic folders import from Files in Simulator and malformed folders fail safely. The remaining proof is selecting and importing the folder through Files on the physical iPad. |
| [6 — Pointer, keyboard, mouse](../GOAL-LOOP.md#goal-6--pointer-keyboard-and-mouse-play) | In progress | Pointer movement, clicking, scrolling, trackpad zoom, attached-keyboard text entry, and existing controls work on device. The recorded coaster-and-scenery end-to-end proof remains. |
| [7 — Finger-first controls](../GOAL-LOOP.md#goal-7--finger-first-controls) | In progress | The device build has touch-sized UI defaults, tap/placement, UI dragging, long-press secondary action, inverted half-speed two-finger pan, deliberate pinch classification, and a touch text-entry fallback. The tester accepts the current stability and control feel; the full finger-only coaster-and-scenery proof remains. |
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
- A signed arm64 build installs and launches on a physical M2 iPad Pro. Device
  logs confirm a read-only bundle, writable Documents/Library paths, and the
  successful indexing of 2,518 objects, 204 track designs, and 57 scenarios.
- User-owned RCT2 data seeded only into the installed app's Documents container
  survives relaunch, and a scenario loads successfully. No proprietary data is
  tracked or copied into the application bundle.
- The attached Magic Keyboard and trackpad retain their existing behavior.
  Finger controls support placement, long press, responsive inverted
  two-finger panning, and a more deliberate pinch threshold. A finger-opened
  text field uses the iPadOS keyboard when available and otherwise exposes an
  app-owned touch keyboard fallback.
- The physical-device tester reports that the build appears stable and works
  with good controls. This is interaction acceptance for the current slice,
  not the Goal 9 performance or 30-minute stress proof.
- The macOS headless loop completed 1,000 ticks with checksum
  `25232284e49cf2cb000000000000000000000000`.

## Physical-device checkpoint

The July 14 signed-device loop used the existing local development signing
configuration without recording team or device identifiers in the repository:

```bash
OPENRCT2_SKIP_MACOS_BUILD=1 \
OPENRCT2_DEVELOPMENT_TEAM=<team> \
OPENRCT2_DEVICE_UDID=<device> \
    ./scripts/build-ios-device.sh signed
OPENRCT2_DEVICE_UDID=<device> ./scripts/install-run-ios.sh
```

The signed build, bundle audit, macOS build, repository safety check, and
1,000-tick headless smoke all passed. The iPadOS version still needs to be
recorded with the next formal device proof.

## Remaining human gates

- Complete one physical-iPad import by choosing the user-owned RCT2 or RCT
  Classic folder through Files, then relaunch and load a scenario.
- Record the full Goal 6 coaster build and scenery placement using only the
  attached pointer/keyboard controls.
- Record the full Goal 7 coaster build and scenery placement using only fingers,
  including text entry. Revisit feel only if that longer flow exposes a gap.

## Remaining goal loop

Close the remaining proofs one goal at a time using the loop in
[`GOAL-LOOP.md`](../GOAL-LOOP.md#the-loop) and the engineering detail in the
master plan's [phase ladder](openrct2-ipados-BUILD-PLAN.md#8-the-phase-by-phase-engineering-plan):

1. **Finish Goal 5:** use the already-working physical build to import through
   Files, relaunch, and load a scenario without proprietary data entering an app
   bundle or archive.
2. **Finish Goal 6:** record a scenario played end-to-end with the already-
   working trackpad or mouse and keyboard, including left/right/middle click,
   scroll, text, shortcuts, coaster construction, and scenery placement.
3. **Finish Goal 7:** record the same MVP flow with the current finger controls,
   including pan, zoom, long press, placement, window interaction, and touch
   text entry.
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
