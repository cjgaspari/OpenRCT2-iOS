# OpenRCT2 Touch agent instructions

These instructions apply to the entire repository.

## Read first

1. `docs/AGENTS.md` — detailed operating manual.
2. `docs/openrct2-ipados-BUILD-PLAN.md` — master reference plan.
3. `GOAL-LOOP.md` — executable goal loop and corrected phase gates.

If the documents disagree with the repository, preserve the non-negotiable safety rules here and update the plan before coding against a false assumption.

## Mission

Deliver a native iPadOS OpenRCT2 MVP that imports user-owned RCT2 data, loads a scenario, supports playable pointer/touch/Pencil controls, sustains at least 30 fps on a mid-size park, and loads one plugin or custom scenario.

## Non-negotiable rules

- Never track, commit, push, copy into an app bundle, archive, or distribute proprietary RCT/RCT2 data. Only `ref/README.md` may be tracked under `ref/`.
- Work only on `ipad` or a short-lived branch merged into `ipad`. Never add commits to `develop`, push to `upstream`, or open an upstream PR.
- Preserve upstream licences, attribution, file headers, `contributors.md`, and history.
- Make small `[touch] ...` commits only after the applicable verification loop is green.
- Run `./scripts/check-repo-safety.sh` before every commit and packaging action.
- Prefer the macOS headless loop, then Simulator, then physical device. Never promote a known-red change.
- Stop for provisioning/signing, proprietary-data packaging risk, repeated dependency dead ends, and touch/Pencil feel judgments.

## Current goal

**Goal 4 — Software framebuffer to Metal presentation.** Present the existing OpenRCT2 software framebuffer through SDL's iOS Metal renderer with correct landscape geometry, Retina scale, safe areas, palette, aspect ratio, resize/lifecycle recreation, and a repeatable Simulator screenshot check.

Update this section only when every exit check for the next goal in `GOAL-LOOP.md` is satisfied.
