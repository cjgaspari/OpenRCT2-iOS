/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Native Mac UI ports (Tier 1–2). TARGET_OS_OSX only — not Catalyst.
 *****************************************************************************/

#pragma once

#include <cstddef>
#include <cstdint>

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

#ifdef __cplusplus
extern "C" {
#endif

/** @return true if a native Mac UI handled presentation (skip engine window). */
bool OpenRCT2MacNativeDebugPaintPresent(void);
bool OpenRCT2MacNativeTransparencyPresent(void);

/** Debug-paint flag indices — must match MacDebugPaintPanel / bridge. */
enum MacDebugPaintFlag : int32_t
{
    MacDebugPaint_WidePaths = 0,
    MacDebugPaint_BlockedTiles = 1,
    MacDebugPaint_SegmentHeights = 2,
    MacDebugPaint_BoundBoxes = 3,
    MacDebugPaint_DirtyVisuals = 4,
    MacDebugPaint_StableSort = 5,
    MacDebugPaint_ForceRedraw = 6,
    MacDebugPaint_Count = 7,
};

bool OpenRCT2MacNativeDebugPaintGet(int32_t flag);
void OpenRCT2MacNativeDebugPaintSet(int32_t flag, bool value);

/** Transparency / see-through — bit flags mirror VIEWPORT_FLAG_HIDE_* / INVISIBLE_*. */
enum MacTransparencyFlag : uint32_t
{
    MacTransparency_HideVegetation = 1u << 0,
    MacTransparency_HideScenery = 1u << 1,
    MacTransparency_HidePaths = 1u << 2,
    MacTransparency_HideRides = 1u << 3,
    MacTransparency_HideVehicles = 1u << 4,
    MacTransparency_HideSupports = 1u << 5,
    MacTransparency_HideGuests = 1u << 6,
    MacTransparency_HideStaff = 1u << 7,
    MacTransparency_InvisibleVegetation = 1u << 8,
    MacTransparency_InvisibleScenery = 1u << 9,
    MacTransparency_InvisiblePaths = 1u << 10,
    MacTransparency_InvisibleRides = 1u << 11,
    MacTransparency_InvisibleVehicles = 1u << 12,
    MacTransparency_InvisibleSupports = 1u << 13,
};

uint32_t OpenRCT2MacNativeTransparencyGet(void);
void OpenRCT2MacNativeTransparencyToggle(uint32_t flag);

/**
 * NSAlert confirm (CJ HIG 1A). Returns 0/1/2 for buttons; -1 cancelled.
 * button1/button2 may be NULL.
 */
int32_t OpenRCT2MacNativeAlertConfirm(
    const char* title, const char* message, const char* button0, const char* button1, const char* button2);

/** @return true if native NSAlert handled the prompt (skip engine window). */
bool OpenRCT2MacNativeSavePromptPresent(void);
bool OpenRCT2MacNativeFireStaffPresent(uint16_t peepId);
bool OpenRCT2MacNativeDemolishRidePresent(uint16_t rideId, bool refurbish);

bool OpenRCT2MacNativeCustomCurrencyPresent(void);
int32_t OpenRCT2MacNativeCustomCurrencyGetRate(void);
void OpenRCT2MacNativeCustomCurrencySetRate(int32_t rate);
void OpenRCT2MacNativeCustomCurrencyGetSymbol(char* out, size_t outLen);
void OpenRCT2MacNativeCustomCurrencySetSymbol(const char* symbol);
int32_t OpenRCT2MacNativeCustomCurrencyGetAffix(void); // 0=prefix, 1=suffix
void OpenRCT2MacNativeCustomCurrencySetAffix(int32_t affix);

/**
 * Modal text field (Tier 1.9). Returns 1=OK, 0=Cancel.
 * On OK, writes UTF-8 into out (nul-terminated, truncated to outLen-1).
 */
int32_t OpenRCT2MacNativeTextInput(
    const char* title, const char* message, const char* initial, char* out, size_t outLen);

/** Changelog / contributors / new-version (2.6). personality: 0=changelog, 1=contributors, 2=newVersion. */
bool OpenRCT2MacNativeChangelogPresent(int32_t personality);
bool OpenRCT2MacNativeChangelogGetText(int32_t personality, char* out, size_t outLen);

bool OpenRCT2MacNativeProgressPresent(const char* text);
void OpenRCT2MacNativeProgressSet(uint32_t current, uint32_t total);
void OpenRCT2MacNativeProgressClose(void);

bool OpenRCT2MacNativeNetworkStatusPresent(const char* text);
void OpenRCT2MacNativeNetworkStatusClose(void);

bool OpenRCT2MacNativeViewClippingPresent(void);
bool OpenRCT2MacNativeViewClippingGetEnabled(void);
void OpenRCT2MacNativeViewClippingSetEnabled(bool enabled);
bool OpenRCT2MacNativeViewClippingGetSeeThrough(void);
void OpenRCT2MacNativeViewClippingSetSeeThrough(bool enabled);
int32_t OpenRCT2MacNativeViewClippingGetHeight(void);
void OpenRCT2MacNativeViewClippingSetHeight(int32_t height);
void OpenRCT2MacNativeViewClippingClearSelection(void);

bool OpenRCT2MacNativeAssetPacksPresent(void);
int32_t OpenRCT2MacNativeAssetPackCount(void);
void OpenRCT2MacNativeAssetPackGetName(int32_t index, char* out, size_t outLen);
bool OpenRCT2MacNativeAssetPackGetEnabled(int32_t index);
void OpenRCT2MacNativeAssetPackSetEnabled(int32_t index, bool enabled);
void OpenRCT2MacNativeAssetPackMove(int32_t index, int32_t direction); // -1 up, +1 down
void OpenRCT2MacNativeAssetPackApply(void);

bool OpenRCT2MacNativeOptionsPresent(void);
bool OpenRCT2MacNativeConfigGetBool(int32_t key);
void OpenRCT2MacNativeConfigSetBool(int32_t key, bool value);
void OpenRCT2MacNativeConfigSave(void);

bool OpenRCT2MacNativeCheatsPresent(void);
bool OpenRCT2MacNativeCheatGet(int32_t type);
void OpenRCT2MacNativeCheatToggle(int32_t type);
void OpenRCT2MacNativeCheatRun(int32_t type, int64_t p1, int64_t p2);

#ifdef __cplusplus
}
#endif

#endif // TARGET_OS_OSX
