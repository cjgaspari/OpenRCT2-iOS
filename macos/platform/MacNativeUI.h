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

/** Object load error (1.11). path + newline-separated "name\\ttype" rows. */
bool OpenRCT2MacNativeObjectLoadErrorPresent(const char* path, const char* rows);

bool OpenRCT2MacNativeShortcutKeysPresent(void);
int32_t OpenRCT2MacNativeShortcutCount(void);
void OpenRCT2MacNativeShortcutGetId(int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeShortcutGetName(int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeShortcutGetChord(int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeShortcutRemove(const char* id);
void OpenRCT2MacNativeShortcutResetAll(void);
bool OpenRCT2MacNativeShortcutChangePresent(const char* id);
void OpenRCT2MacNativeShortcutApplyChord(const char* id, const char* chord);

bool OpenRCT2MacNativeThemesPresent(void);
int32_t OpenRCT2MacNativeThemeCount(void);
void OpenRCT2MacNativeThemeGetName(int32_t index, char* out, size_t outLen);
int32_t OpenRCT2MacNativeThemeGetActive(void);
void OpenRCT2MacNativeThemeSetActive(int32_t index);
uint8_t OpenRCT2MacNativeThemeGetFlags(void);
void OpenRCT2MacNativeThemeToggleFlag(uint8_t flag);

bool OpenRCT2MacNativeNewCampaignPresent(int16_t campaignType);
int32_t OpenRCT2MacNativeCampaignRideCount(int16_t campaignType);
void OpenRCT2MacNativeCampaignRideName(int16_t campaignType, int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeCampaignStart(int16_t campaignType, int32_t rideIndex, int32_t weeks);

/** Title / Tier-3 browsers — Liquid Glass chrome, dense lists. */
bool OpenRCT2MacNativeScenarioSelectPresent(void);
bool OpenRCT2MacNativeLoadParkPresent(void);

int32_t OpenRCT2MacNativeScenarioTabCount(void);
bool OpenRCT2MacNativeScenarioTabVisible(int32_t tab);
void OpenRCT2MacNativeScenarioTabName(int32_t tab, char* out, size_t outLen);
int32_t OpenRCT2MacNativeScenarioGetActiveTab(void);
void OpenRCT2MacNativeScenarioSetActiveTab(int32_t tab);
int32_t OpenRCT2MacNativeScenarioRowCount(void);
int32_t OpenRCT2MacNativeScenarioRowKind(int32_t row);
void OpenRCT2MacNativeScenarioRowName(int32_t row, char* out, size_t outLen);
void OpenRCT2MacNativeScenarioRowDetails(int32_t row, char* out, size_t outLen);
bool OpenRCT2MacNativeScenarioRowLocked(int32_t row);
bool OpenRCT2MacNativeScenarioSelectRow(int32_t row);
void OpenRCT2MacNativeScenarioRequestPreview(int32_t row);

void OpenRCT2MacNativeSaveFileRefresh(void);
int32_t OpenRCT2MacNativeSaveFileCount(void);
void OpenRCT2MacNativeSaveFileGetName(int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeSaveFileGetDate(int32_t index, char* out, size_t outLen);
bool OpenRCT2MacNativeSaveFileLoad(int32_t index);

/** Live Glass Style Lab — knobs for clear/regular, dimming, frost, tint. */
bool OpenRCT2MacNativeGlassStyleLabPresent(void);

/** UI Lab — native vs classic per surface (persisted). */
bool OpenRCT2MacNativeUILabPresent(void);
/** @return false → Present should fall back to classic engine UI. */
bool OpenRCT2MacUINativeEnabled(const char* surfaceId);
/** Called when a UI Lab surface toggle changes (recreate title/chrome as needed). */
void OpenRCT2MacUINotifySurfaceChanged(const char* surfaceId);
/** Classic engine toolbars when park glass HUD is disabled in UI Lab. */
bool OpenRCT2MacShouldCreateDesktopChromeWindows(void);
int32_t OpenRCT2MacLiquidGlassChromeTopInset(void);

/** Recent news (3.1) — glass dense archive list. */
bool OpenRCT2MacNativeRecentNewsPresent(void);
void OpenRCT2MacNativeNewsRefresh(void);
int32_t OpenRCT2MacNativeNewsCount(void);
void OpenRCT2MacNativeNewsGetDate(int32_t index, char* out, size_t outLen);
void OpenRCT2MacNativeNewsGetText(int32_t index, char* out, size_t outLen);
bool OpenRCT2MacNativeNewsHasSubject(int32_t index);
bool OpenRCT2MacNativeNewsHasLocation(int32_t index);
void OpenRCT2MacNativeNewsOpenSubject(int32_t index);
void OpenRCT2MacNativeNewsLocate(int32_t index);

#ifdef __cplusplus
}

#include <functional>
#include <string_view>

#include <openrct2/interface/WindowTypes.h>

namespace OpenRCT2::Ui
{
    /** Store scenario-select callback then present Mac glass picker. */
    bool MacNativeScenarioSelectOpen(std::function<void(std::string_view)> callback);
    /** Present Mac glass load-park browser (registers FileBrowser callback). */
    bool MacNativeLoadParkOpen(std::function<void(ModalResult, std::string_view)> callback, bool isJsCallback);
} // namespace OpenRCT2::Ui
#endif

#endif // TARGET_OS_OSX
