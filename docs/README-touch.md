# OpenRCT2 Touch technical overview

OpenRCT2 Touch is an unofficial, independent iPadOS fork of
[OpenRCT2](https://github.com/OpenRCT2/OpenRCT2). It runs natively on iPadOS
with finger controls and retains attached keyboard, mouse, and trackpad input.
It is not affiliated with, endorsed by, or supported by the OpenRCT2 team.

The canonical user-facing description, requirements, physical-device build
instructions, Files import walkthrough, controls, troubleshooting, and known
limitations are maintained in the repository's [root README](../readme.md).
Keeping the installation procedure in one place prevents release instructions
from drifting.

## Verified scope

- Native ARM64 iPadOS application using SDL's iOS Metal presentation path.
- User-owned RCT2 or RCT Classic data imported into private app storage.
- Attached keyboard, mouse, and trackpad behavior.
- Finger placement, painting and removal, two-finger pan/pinch/rotation, and
  native iPadOS text entry.
- Repository and app-bundle audits that reject proprietary game data.

Apple Pencil and multiplayer are not supported. Plugin/custom-scenario loading,
formal performance testing, and the complete physical Files-import proof remain
release gates rather than advertised features.

## Engineering references

- [Current verified status](DEVELOPMENT-STATUS.md)
- [Touch controls and decision history](TOUCH-CONTROLS.md)
- [Release checklist](RELEASE-CHECKLIST.md)
- [Executable goal loop](../GOAL-LOOP.md)
- [Master iPadOS build plan](openrct2-ipados-BUILD-PLAN.md)

## Licence and data boundary

The fork remains GPLv3-or-later and preserves upstream history, copyright
notices, [`licence.txt`](../licence.txt), and
[`contributors.md`](../contributors.md). New port code is distributed on the
same terms. See [`NOTICE.md`](../NOTICE.md) for attribution and distribution
notices.

No RollerCoaster Tycoon game data is distributed. Users must provide data from
a copy they legally own, and the project safety checks forbid proprietary data
from tracked files, app bundles, archives, and release packages.
