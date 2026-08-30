# OpenRCT2 Touch agent instructions

These instructions apply to the entire repository.

## Read first

1. `docs/AGENTS.md` — detailed operating manual.
2. `docs/openrct2-ipados-BUILD-PLAN.md` — master reference plan.
3. `docs/DEVELOPMENT-STATUS.md` — verified checkpoint and remaining device gate.
4. `GOAL-LOOP.md` — executable goal loop and corrected phase gates.

If the documents disagree with the repository, preserve the non-negotiable safety rules here and update the plan before coding against a false assumption.

## Mission

Deliver a native iPadOS OpenRCT2 MVP that imports user-owned RCT2 data, loads a scenario, supports playable pointer and finger controls, sustains at least 30 fps on a mid-size park, and loads one plugin or custom scenario. Apple Pencil and multiplayer are outside the current release scope. The live device contract is a universal iPhone and iPad build that supports portrait and landscape.

## Non-negotiable rules

- Never track, commit, push, archive, or distribute proprietary RCT/RCT2 data. Only `ref/README.md` may be tracked under `ref/`. A local Simulator `.app` under `build/` may copy ignored `ref/rct2` for personal installs; never put that payload in git, an IPA, or an xcarchive.
- Work only on `ipad` or a short-lived branch merged into `ipad`. Never add commits to `develop`, push to `upstream`, or open an upstream PR.
- Preserve upstream licences, attribution, file headers, `contributors.md`, and history.
- Make small `[touch] ...` commits only after the applicable verification loop is green.
- Run `./scripts/check-repo-safety.sh` before every commit and packaging action.
- Prefer the macOS headless loop, then Simulator, then physical device. Never promote a known-red change.
- Stop for provisioning/signing, any git/IPA/xcarchive packaging of proprietary data, repeated dependency dead ends, and touch-control feel judgments.

## Device play

Install and launch on the connected iPhone (prefers CJ’s iPhone Air):

```sh
./scripts/play-ios-device.sh
```

Team and UDID live in gitignored `runtime/device.env` (copy `scripts/device.env.example` once). Unlock the phone before launch. Pass `--console` only when you need streamed device logs. Do not put team or UDID in git, docs, or commits.

## Current goal

**Goal 6 — Pointer, keyboard, and mouse play** remains the formal ladder goal. The live engineering slice is the **native SwiftUI park chrome** on a fluidly resizable, rotatable scene: status (Park) on the leading top edge, pause/speed on the trailing top edge, View/rotate on the leading thumb (stacked in portrait, side-by-side in compact-height landscape), and a trailing Build hammer. Standard status/Home UI remains visible, system edge gestures take precedence, and interactive chrome uses safe, corner-adapted margins. Goal 6/7 end-to-end device proofs remain.

Update this section only when every exit check for the next goal in `GOAL-LOOP.md` is satisfied.
