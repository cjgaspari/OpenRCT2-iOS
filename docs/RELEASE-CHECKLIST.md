# OpenRCT2 Touch release checklist

This checklist separates a public source preview from a binary release. Do not
describe a source preview as an installable public iPad release.

## Release types

### Source-only developer preview

This publishes the `ipad` branch and a tagged source snapshot. Users build and
sign the app themselves with Xcode. It may be released when every source gate
below passes, even if the remaining physical-device acceptance gates are
clearly disclosed.

### Local unsigned IPA

`./scripts/package-ios-ipa.sh` may package the audited device app for local
signing work. The script rejects embedded signatures, provisioning profiles,
and proprietary RCT/RCT2 data. This ignored build artifact is not a public
binary beta and cannot be installed on ordinary devices until it is signed for
an appropriate Apple distribution channel.

### Binary beta

This distributes an `.ipa` or TestFlight build. In addition to every source
gate, it requires a selected Apple distribution channel, a non-ephemeral
provisioning profile appropriate to that channel, the exact corresponding
source commit, complete licence notices, and the full physical-iPad acceptance
record. A Personal Team development build is not a public binary beta.

## Source gates

- [ ] Work is on `ipad`, the working tree is clean, and the release commit is
  pushed to `origin/ipad`.
- [ ] `./scripts/check-repo-safety.sh` passes.
- [ ] `git ls-files ref` reports only `ref/README.md`.
- [ ] The root README accurately states the supported controls, disabled
  features, installation method, signing limitations, and remaining gates.
- [ ] Apple Pencil and multiplayer are described as unsupported.
- [ ] `./scripts/bootstrap.sh` passes without requiring proprietary data.
- [ ] With local user-owned data, `./scripts/bootstrap.sh --require-data`,
  `./scripts/build-macos.sh`, and `./scripts/run-macos-headless.sh` pass.
- [ ] `./scripts/build-ios-deps.sh all` and `./scripts/build-ios.sh all` pass.
- [ ] Both app bundles pass `./scripts/verify-ios-bundle.sh`.
- [ ] If a local unsigned IPA is needed, `./scripts/package-ios-ipa.sh` passes
  and its SHA-256 digest is recorded with the test handoff.
- [ ] No tracked file or commit contains a signing team, device identifier,
  provisioning profile, `.ipa`, `.xcarchive`, or proprietary game asset.
- [ ] A release tag and release notes identify the upstream base and the exact
  OpenRCT2 Touch commit.

## Physical-iPad acceptance

- [ ] Install into a fresh app sandbox using the documented commands.
- [ ] Choose a user-owned RCT2 or RCT Classic folder through Files.
- [ ] Confirm validation and import complete without changing the source.
- [ ] Load a scenario, terminate the app, relaunch, and load it again.
- [ ] Complete the pointer/keyboard coaster-and-scenery script.
- [ ] Complete the finger-only coaster-and-scenery script, including text.
- [ ] Record the device model, iPadOS version, build commit, and result.
- [ ] Run the agreed mid-size park at 30 fps or better.
- [ ] Complete the 30-minute stress session and record any crashes.
- [ ] Load one legally redistributable plugin or custom scenario on-device.

## Binary-package gates

- [ ] Select and document the channel: registered-device/ad hoc or TestFlight.
- [ ] Use an Apple Developer Program team and a profile valid for that channel;
  do not publish a Personal Team development artifact.
- [ ] Archive from the tagged, clean release commit.
- [ ] Confirm the app identifier is `com.chrissotraidis.openrct2touch`.
- [ ] Confirm the application contains `Licences/GPL-3.0-or-later.txt`, upstream
  contributors, the Touch notice, the dependency manifest, and each bundled
  dependency's licence text.
- [ ] Run the bundle verifier against the exact archived application.
- [ ] Inspect the archive or IPA for `g1.dat`, `RCT2.EXE`, `ObjData`, scenarios,
  saves, tracks, provisioning secrets, and other unintended files.
- [ ] Publish or link the exact corresponding GPL source at the same time as
  the binary.
- [ ] Install the exported build through the selected channel on a second
  registered device and rerun the complete demo.

## Release language

Until all binary and physical gates pass, use:

> OpenRCT2 Touch is a source-only developer preview. It runs natively on iPad,
> but users currently build and sign it themselves and must import data from a
> legally owned copy of RCT2 or RCT Classic.

Do not use “official,” “App Store version,” “public IPA,” “Pencil support,”
“multiplayer support,” or “installable MVP” unless the relevant facts change
and this checklist is updated with evidence.
