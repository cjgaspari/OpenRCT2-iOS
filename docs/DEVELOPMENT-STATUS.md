# OpenRCT2 Touch development status

- **Last updated:** July 16, 2026
- **Working branch:** `ipad`
- **Current goal:** [Goal 5 — Sandbox paths and user-owned data import](../GOAL-LOOP.md#goal-5--sandbox-paths-and-user-owned-data-import)
- **Accepted checkpoint:** native text input and the July 16 touch-control pass

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
| [7 — Finger-first controls](../GOAL-LOOP.md#goal-7--finger-first-controls) | In progress | The current touch mapping is accepted on device: tap/placement, UI dragging, long-press secondary action, inverted half-speed pan, pinch, native text entry, paint/remove dragging, and construction rotation. The full finger-only coaster-and-scenery proof remains. |
| [8 — Release hygiene](../GOAL-LOOP.md#goal-8--release-documentation-and-package-hygiene) | Complete | Canonical install docs, honest feature boundaries, fork support paths, maintainer-owned bundle identity, CI safety checks, and embedded licence notices pass clean device and Simulator bundle audits. |
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
  two-finger panning, and a more deliberate pinch threshold. The app-owned
  keyboard fallback was removed after device testing found that it obscured
  in-game text fields.
- The physical-device tester reports that the build appears stable and works
  with good controls. This is interaction acceptance for the current slice,
  not the Goal 9 performance or 30-minute stress proof.
- The July 16 device pass accepted native conditional text entry, one-finger
  placement and paint dragging, two-finger pan and pinch, 15-degree
  construction rotation, and two-finger tap or hold-drag footpath removal.
- The production `AppIcon` asset catalog compiles an opaque 1024px source into
  the required iPad icon renditions. The last device-tested build was bundle
  build 2 under the former identifier. The current release-hygiene patch moves
  to build 3 and `com.chrissotraidis.openrct2touch`; it intentionally creates a
  fresh sandbox and therefore requires one new import during device acceptance.
- The macOS headless loop completed 1,000 ticks with checksum
  `25232284e49cf2cb000000000000000000000000`.
- Goal 8 release hygiene passes: `./scripts/check-touch-release-safety.sh`,
  `./scripts/build-ios.sh all`, both strengthened bundle audits, and the macOS
  headless loop are green. GitHub Issues is enabled with an iPad-specific form.

## Current interaction checkpoint

- Native text entry is device-confirmed: iPadOS shows its software keyboard when
  the hardware keyboard is detached and correctly leaves it hidden while the
  attached keyboard is available.
- Active placement follows one-finger movement correctly. The confirmation
  double-tap window at 390 ms is accepted at the current checkpoint.
- Hold-then-drag now maps to the engine's existing mouse tool-drag behavior for
  footpath, land, water, and clear-scenery tools. Footpath painting is
  device-confirmed. Two-finger secondary tap removes one path segment and a
  two-finger hold-drag removes continuously; both are device-confirmed without
  changing mouse or trackpad right-click removal.
- A bounded two-finger rotation prototype is enabled only for active scenery,
  ride-construction, and track-design placement tools. Its 15-degree start
  threshold and delayed pan arbitration are accepted at this checkpoint.

The full mapping and decision history are maintained in
[`TOUCH-CONTROLS.md`](TOUCH-CONTROLS.md).

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
4. **Goal 9:** sustain at least 30 fps on the agreed mid-size park and complete a
   30-minute stress run without an out-of-memory failure; fix the top three
   reproducible device crashes.
5. **Goal 10:** load one plugin or custom scenario, audit the distributable for
   proprietary assets, install through the chosen private channel, and pass the
   complete physical-iPad MVP demo.

Every goal closes only when its exit proof in [`GOAL-LOOP.md`](../GOAL-LOOP.md#goal-ladder-and-exit-proofs)
is green. Physical signing, touch feel, and any asset-packaging risk stay
explicit human gates.
