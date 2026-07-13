# iOS dependency manifest

This file records the reproducible dependency closure for OpenRCT2 Touch. Built libraries and source caches under `vendor/` are local, ignored outputs; this manifest and `vcpkg.json` are tracked inputs.

## Build contract

- Package manager: vcpkg at commit `f87344cac03158cbf1467264565f1fd36b382a24`.
- Manifest: root `vcpkg.json`, pinned by `builtin-baseline` to the same commit.
- Device triplet: tracked overlay `ios/vcpkg-triplets/openrct2-arm64-ios.cmake`; based on vcpkg community `arm64-ios`, with explicit Autoconf host/build tuples and ICU's Darwin make fragment; static libraries, arm64, iPhoneOS SDK.
- Simulator triplet: tracked overlay `ios/vcpkg-triplets/openrct2-arm64-ios-simulator.cmake`; based on vcpkg community `arm64-ios-simulator`, with the same Autoconf/ICU correction; static libraries, arm64, iPhoneSimulator SDK.
- Minimum deployment target: iOS/iPadOS 15.0.
- Build command: `./scripts/build-ios-deps.sh all`.
- Verification: `ios/deps-smoke` includes and calls one public symbol from every direct dependency, links an executable for each slice, and records its Mach-O platform with `vtool`.
- Licences: vcpkg installs each dependency's upstream licence text under `vendor/ios-arm64/<triplet>/share/<port>/copyright` and the equivalent Simulator tree. Those generated copies remain untracked; the upstream licence identifiers are listed below.

## Direct dependencies

Hashes below are SHA-512 values from the exact vcpkg port definitions at the pinned baseline. A `#N` suffix is the vcpkg port revision.

| Dependency | Source | Version | Source archive SHA-512 | Licence | Build features | Verified slices |
| --- | --- | --- | --- | --- | --- | --- |
| SDL2 | `https://github.com/libsdl-org/SDL`, tag `release-2.32.10` | `2.32.10#1` | `d5622d6bb7266f7942a7b8ad43e8a22524893bf0c2ea1af91204838d9b78d32768843f6faa248757427b8404b8c6443776d4afa6b672cd8571a4e0c03a829383` | Zlib | static; vcpkg default features disabled | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| ICU4C | `https://github.com/unicode-org/icu/releases/download/release-78.3/icu4c-78.3-sources.tgz` | `78.3#1` | `04a49455e1489030c520a4bfd2664fa2171e7938d08f2acdbbcb1fda976639fd8b1f0704f2eec89ba59a7b6d118ceaab6ec5a096e40d9085a0895d91ce225245` | ICU | static; `uc` + data; host tools; samples/tests/layout disabled; explicit `aarch64-apple-ios` cross tuple and `mh-darwin` fragment | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| FreeType | `https://gitlab.freedesktop.org/freetype/freetype`, tag `VER-2-14-3` | `2.14.3` | `c3b6b0cc4b428c9c647ab2148386901dfd315273b68051940e8fea6010d46fdd2913467c3ef58be0d499b8e2ef5a0f1a4cc5e739756155587f4f7dff08ef9695` | FTL OR GPL-2.0-or-later | static; only `png` and `zlib` features | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| libpng | `https://github.com/pnggroup/libpng`, tag `v1.6.58` | `1.6.58` | `65f54d805e1f7c46a5fc335b984e4cbd4f934e0f02fbf6673c13800b49a4c11fbeb4098eebfb33079527a56c3d933e97631f91ab68dbb31442982784f9241ace` | libpng-2.0 | static; APNG feature disabled | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| zlib | `https://github.com/madler/zlib`, tag `v1.3.2` | `1.3.2#1` | `16fea4df307a68cf0035858abe2fd550250618a97590e202037acd18a666f57afc10f8836cbbd472d54a0e76539d0e558cb26f059d53de52ff90634bbf4f47d4` | Zlib | static | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| zstd | `https://github.com/facebook/zstd`, tag `v1.5.7` | `1.5.7` | `26e441267305f6e58080460f96ab98645219a90d290a533410b1b0b1d2f870721c95f8384e342ee647c5e968385a5b7e30c2d04340c37f59b3e6d86762c3260c` | BSD-3-Clause OR GPL-2.0-only | static | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| libzip | `https://github.com/nih-at/libzip`, tag `v1.11.4` | `1.11.4` | `940a6e1145d6e0f2bd40577b4fa13f9c8e2115b267fb632dfb2443998a67d3e5de9a2026df5380c9b1b2fb181967d2f4dfd0929a9970d8bb196079a153a17bcc` | BSD-3-Clause | static; default AES/OpenSSL and bzip2 features disabled | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |
| nlohmann JSON | `https://github.com/nlohmann/json`, tag `v3.12.0` | `3.12.0#2` | `6cc1e86261f8fac21cc17a33da3b6b3c3cd5c116755651642af3c9e99bb3538fd42c1bd50397a77c8fb6821bc62d90e6b91bcdde77a78f58f2416c62fc53b97d` | MIT | header-only; vcpkg default features | iOS arm64, min 15.0; iOS Simulator arm64, min 15.0 |

The successful smoke binaries report `platform IOS` and `platform IOSSIMULATOR`, respectively, through `vtool -show-build`; both report `minos 15.0`, `sdk 26.5`, and Mach-O arm64.

## Initially disabled engine features

The top-level CMake defaults these features off whenever `CMAKE_SYSTEM_NAME=iOS`: desktop OpenGL, HTTP, multiplayer networking, FLAC, Vorbis, and Discord RPC. `ENABLE_SCRIPTING` remains on. FreeType remains in the initial closure so TTF support can stay enabled.
