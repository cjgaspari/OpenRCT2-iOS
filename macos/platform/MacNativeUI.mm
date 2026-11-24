/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

#include "MacNativeUI.h"

#include <openrct2-ui/interface/Window.h>
#include <openrct2-ui/windows/Windows.h>
#include <openrct2/AssetPack.h>
#include <openrct2/AssetPackManager.h>
#include <openrct2-ui/UiContext.h>
#include <openrct2-ui/input/ShortcutManager.h>
#include <openrct2-ui/interface/Theme.h>
#include <openrct2/Cheats.h>
#include <openrct2/actions/park/ParkMarketingAction.h>
#include <openrct2/management/Marketing.h>
#include <openrct2/ride/Ride.h>
#include <openrct2/ride/RideData.h>
#include <openrct2/ride/RideManager.hpp>
#include <openrct2/ride/ShopItem.h>
#include <openrct2/Context.h>
#include <openrct2/localisation/Language.h>
#include <openrct2/Game.h>
#include <openrct2/GameState.h>
#include <openrct2/OpenRCT2.h>
#include <openrct2/PlatformEnvironment.h>
#include <openrct2/Version.h>
#include <openrct2/interface/Window.h>
#include <openrct2/ui/UiContext.h>
#include <openrct2/actions/GameActionRunner.h>
#include <openrct2/actions/ride/RideDemolishAction.h>
#include <openrct2/actions/peep/StaffFireAction.h>
#include <openrct2/audio/Audio.h>
#include <openrct2/config/Config.h>
#include <openrct2/core/BitSet.hpp>
#include <openrct2/core/EnumUtils.hpp>
#include <openrct2/core/File.h>
#include <openrct2/drawing/Drawing.h>
#include <openrct2/entity/Peep.h>
#include <openrct2/localisation/Currency.h>
#include <openrct2/ui/WindowManager.h>
#include <openrct2/interface/Viewport.h>
#include <openrct2/network/Network.h>
#include <openrct2/object/ObjectManager.h>
#include <openrct2/paint/Paint.h>
#include <openrct2/paint/tile_element/Paint.TileElement.h>
#include <openrct2/windows/Intent.h>
#include <openrct2/world/Map.h>
#include <openrct2/world/MapSelection.h>
#include <openrct2/world/Park.h>

#include <algorithm>
#include <cstdio>
#include <memory>
#include <pthread.h>
#include <sstream>
#include <string>
#include <vector>

#import <Foundation/Foundation.h>

using namespace OpenRCT2;
using namespace OpenRCT2::Ui;
using namespace OpenRCT2::Ui::Windows;

extern "C" bool OpenRCT2MacNativeDebugPaintShow(void);
extern "C" bool OpenRCT2MacNativeTransparencyShow(void);
extern "C" int32_t OpenRCT2MacNativeAlertConfirm(
    const char* title, const char* message, const char* button0, const char* button1, const char* button2);

bool OpenRCT2MacNativeDebugPaintPresent(void)
{
    return OpenRCT2MacNativeDebugPaintShow();
}

bool OpenRCT2MacNativeTransparencyPresent(void)
{
    return OpenRCT2MacNativeTransparencyShow();
}

bool OpenRCT2MacNativeDebugPaintGet(int32_t flag)
{
    switch (flag)
    {
        case MacDebugPaint_WidePaths:
            return gPaintWidePathsAsGhost;
        case MacDebugPaint_BlockedTiles:
            return gPaintBlockedTiles;
        case MacDebugPaint_SegmentHeights:
            return gShowSupportSegmentHeights;
        case MacDebugPaint_BoundBoxes:
            return gPaintBoundingBoxes;
        case MacDebugPaint_DirtyVisuals:
            return gShowDirtyVisuals;
        case MacDebugPaint_StableSort:
            return gPaintStableSort;
        case MacDebugPaint_ForceRedraw:
            return gPaintForceRedraw;
        default:
            return false;
    }
}

void OpenRCT2MacNativeDebugPaintSet(int32_t flag, bool value)
{
    switch (flag)
    {
        case MacDebugPaint_WidePaths:
            gPaintWidePathsAsGhost = value;
            break;
        case MacDebugPaint_BlockedTiles:
            gPaintBlockedTiles = value;
            break;
        case MacDebugPaint_SegmentHeights:
            gShowSupportSegmentHeights = value;
            break;
        case MacDebugPaint_BoundBoxes:
            gPaintBoundingBoxes = value;
            break;
        case MacDebugPaint_DirtyVisuals:
            gShowDirtyVisuals = value;
            break;
        case MacDebugPaint_StableSort:
            gPaintStableSort = value;
            break;
        case MacDebugPaint_ForceRedraw:
            gPaintForceRedraw = value;
            break;
        default:
            return;
    }
    GfxInvalidateScreen();
}

static uint32_t MapViewportToMac(uint32_t wflags)
{
    uint32_t out = 0;
    if (wflags & VIEWPORT_FLAG_HIDE_VEGETATION)
        out |= MacTransparency_HideVegetation;
    if (wflags & VIEWPORT_FLAG_HIDE_SCENERY)
        out |= MacTransparency_HideScenery;
    if (wflags & VIEWPORT_FLAG_HIDE_PATHS)
        out |= MacTransparency_HidePaths;
    if (wflags & VIEWPORT_FLAG_HIDE_RIDES)
        out |= MacTransparency_HideRides;
    if (wflags & VIEWPORT_FLAG_HIDE_VEHICLES)
        out |= MacTransparency_HideVehicles;
    if (wflags & VIEWPORT_FLAG_HIDE_SUPPORTS)
        out |= MacTransparency_HideSupports;
    if (wflags & VIEWPORT_FLAG_HIDE_GUESTS)
        out |= MacTransparency_HideGuests;
    if (wflags & VIEWPORT_FLAG_HIDE_STAFF)
        out |= MacTransparency_HideStaff;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_VEGETATION)
        out |= MacTransparency_InvisibleVegetation;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_SCENERY)
        out |= MacTransparency_InvisibleScenery;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_PATHS)
        out |= MacTransparency_InvisiblePaths;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_RIDES)
        out |= MacTransparency_InvisibleRides;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_VEHICLES)
        out |= MacTransparency_InvisibleVehicles;
    if (wflags & VIEWPORT_FLAG_INVISIBLE_SUPPORTS)
        out |= MacTransparency_InvisibleSupports;
    return out;
}

static uint32_t MacFlagToViewport(uint32_t flag)
{
    switch (flag)
    {
        case MacTransparency_HideVegetation:
            return VIEWPORT_FLAG_HIDE_VEGETATION;
        case MacTransparency_HideScenery:
            return VIEWPORT_FLAG_HIDE_SCENERY;
        case MacTransparency_HidePaths:
            return VIEWPORT_FLAG_HIDE_PATHS;
        case MacTransparency_HideRides:
            return VIEWPORT_FLAG_HIDE_RIDES;
        case MacTransparency_HideVehicles:
            return VIEWPORT_FLAG_HIDE_VEHICLES;
        case MacTransparency_HideSupports:
            return VIEWPORT_FLAG_HIDE_SUPPORTS;
        case MacTransparency_HideGuests:
            return VIEWPORT_FLAG_HIDE_GUESTS;
        case MacTransparency_HideStaff:
            return VIEWPORT_FLAG_HIDE_STAFF;
        case MacTransparency_InvisibleVegetation:
            return VIEWPORT_FLAG_INVISIBLE_VEGETATION;
        case MacTransparency_InvisibleScenery:
            return VIEWPORT_FLAG_INVISIBLE_SCENERY;
        case MacTransparency_InvisiblePaths:
            return VIEWPORT_FLAG_INVISIBLE_PATHS;
        case MacTransparency_InvisibleRides:
            return VIEWPORT_FLAG_INVISIBLE_RIDES;
        case MacTransparency_InvisibleVehicles:
            return VIEWPORT_FLAG_INVISIBLE_VEHICLES;
        case MacTransparency_InvisibleSupports:
            return VIEWPORT_FLAG_INVISIBLE_SUPPORTS;
        default:
            return 0;
    }
}

static uint32_t SeeThroughCompanion(uint32_t invisibleFlag)
{
    switch (invisibleFlag)
    {
        case VIEWPORT_FLAG_INVISIBLE_VEGETATION:
            return VIEWPORT_FLAG_HIDE_VEGETATION;
        case VIEWPORT_FLAG_INVISIBLE_SCENERY:
            return VIEWPORT_FLAG_HIDE_SCENERY;
        case VIEWPORT_FLAG_INVISIBLE_PATHS:
            return VIEWPORT_FLAG_HIDE_PATHS;
        case VIEWPORT_FLAG_INVISIBLE_RIDES:
            return VIEWPORT_FLAG_HIDE_RIDES;
        case VIEWPORT_FLAG_INVISIBLE_VEHICLES:
            return VIEWPORT_FLAG_HIDE_VEHICLES;
        case VIEWPORT_FLAG_INVISIBLE_SUPPORTS:
            return VIEWPORT_FLAG_HIDE_SUPPORTS;
        default:
            return 0;
    }
}

uint32_t OpenRCT2MacNativeTransparencyGet(void)
{
    auto* w = WindowGetMain();
    if (w == nullptr || w->viewport == nullptr)
        return 0;
    return MapViewportToMac(w->viewport->flags);
}

void OpenRCT2MacNativeTransparencyToggle(uint32_t flag)
{
    auto* w = WindowGetMain();
    if (w == nullptr || w->viewport == nullptr)
        return;

    uint32_t wflags = w->viewport->flags;
    const uint32_t vpFlag = MacFlagToViewport(flag);
    if (vpFlag == 0)
        return;

    const uint32_t companion = SeeThroughCompanion(vpFlag);
    if (companion != 0)
    {
        // Invisible toggles: match TransparencyWindow::ToggleTransparency
        wflags ^= vpFlag;
        if (wflags & vpFlag)
            wflags |= companion;
    }
    else
    {
        wflags ^= vpFlag;
    }

    if (w->viewport->flags == wflags)
        return;

    w->viewport->flags = wflags;
    w->invalidate();

    Config::Get().general.invisibleRides = wflags & VIEWPORT_FLAG_INVISIBLE_RIDES;
    Config::Get().general.invisibleVehicles = wflags & VIEWPORT_FLAG_INVISIBLE_VEHICLES;
    Config::Get().general.invisibleScenery = wflags & VIEWPORT_FLAG_INVISIBLE_SCENERY;
    Config::Get().general.invisibleTrees = wflags & VIEWPORT_FLAG_INVISIBLE_VEGETATION;
    Config::Get().general.invisiblePaths = wflags & VIEWPORT_FLAG_INVISIBLE_PATHS;
    Config::Get().general.invisibleSupports = wflags & VIEWPORT_FLAG_INVISIBLE_SUPPORTS;
    Config::Save();
}

static void MacNativePauseForModal()
{
    if (Network::GetMode() == Network::Mode::none)
    {
        gGamePaused |= GAME_PAUSED_MODAL;
        Audio::StopAll();
    }
}

static void MacNativeUnpauseAfterModal()
{
    if (Network::GetMode() == Network::Mode::none)
    {
        gGamePaused &= ~GAME_PAUSED_MODAL;
        Audio::Resume();
    }
}

bool OpenRCT2MacNativeSavePromptPresent(void)
{
    MacNativePauseForModal();

    const bool trackEditor = isInTrackDesignerOrManager();
    int32_t choice = -1;
    if (trackEditor)
    {
        choice = OpenRCT2MacNativeAlertConfirm(
            "Quit OpenRCT2", "Are you sure you want to quit?", "OK", "Cancel", nullptr);
        MacNativeUnpauseAfterModal();
        if (choice == 0)
            GameLoadOrQuitNoSavePrompt();
        return true;
    }

    choice = OpenRCT2MacNativeAlertConfirm(
        "Save Game", "Do you want to save the game before continuing?", "Save", "Don't Save", "Cancel");
    MacNativeUnpauseAfterModal();

    if (choice == 0)
    {
        std::unique_ptr<Intent> intent;
        if (isInEditorMode())
        {
            intent = std::make_unique<Intent>(WindowClass::loadsave);
            intent->PutEnumExtra<LoadSaveAction>(INTENT_EXTRA_LOADSAVE_ACTION, LoadSaveAction::save);
            intent->PutEnumExtra<LoadSaveType>(INTENT_EXTRA_LOADSAVE_TYPE, LoadSaveType::landscape);
            intent->PutExtra(INTENT_EXTRA_PATH, getGameState().scenarioOptions.name);
        }
        else
        {
            intent = CreateSaveGameAsIntent();
        }
        // Match classic: after Save, continue via loadsave callback when OK.
        // Classic attaches WindowSavePromptCallback — keep engine loadsave for file pick.
        ContextOpenIntent(intent.get());
    }
    else if (choice == 1)
    {
        GameLoadOrQuitNoSavePrompt();
    }
    return true;
}

bool OpenRCT2MacNativeFireStaffPresent(uint16_t peepId)
{
    auto* peep = getGameState().entities.TryGetEntity<Peep>(EntityId::FromUnderlying(peepId));
    if (peep == nullptr)
        return false;

    const char* name = (peep->name != nullptr && peep->name[0] != '\0') ? peep->name : "this staff member";
    char message[256];
    std::snprintf(message, sizeof(message), "Are you sure you want to fire %s?", name);

    MacNativePauseForModal();
    const int32_t choice = OpenRCT2MacNativeAlertConfirm("Sack Staff", message, "Yes", "Cancel", nullptr);
    MacNativeUnpauseAfterModal();
    if (choice == 0)
    {
        auto action = GameActions::StaffFireAction(EntityId::FromUnderlying(peepId));
        GameActions::Execute(&action, getGameState());
    }
    return true;
}

bool OpenRCT2MacNativeDemolishRidePresent(uint16_t rideId, bool refurbish)
{
    auto* ride = GetRide(RideId::FromUnderlying(rideId));
    if (ride == nullptr)
        return false;

    // Classic uses STR_* + formatNameTo; English stand-in keeps 1:1 actions.
    const char* name = !ride->customName.empty() ? ride->customName.c_str() : "this ride";
    char message[256];
    if (refurbish)
        std::snprintf(message, sizeof(message), "Refurbish %s?", name);
    else
        std::snprintf(message, sizeof(message), "Demolish %s?", name);

    MacNativePauseForModal();
    const int32_t choice = OpenRCT2MacNativeAlertConfirm(
        refurbish ? "Refurbish Ride" : "Demolish Ride", message, refurbish ? "Refurbish" : "Demolish", "Cancel",
        nullptr);
    MacNativeUnpauseAfterModal();
    if (choice == 0)
    {
        auto action = GameActions::RideDemolishAction(
            RideId::FromUnderlying(rideId),
            refurbish ? GameActions::RideModifyType::renew : GameActions::RideModifyType::demolish);
        GameActions::Execute(&action, getGameState());
    }
    return true;
}

// OpenRCT2MacNativeAlertConfirm is implemented in MacNativeAlerts.swift.

extern "C" bool OpenRCT2MacNativeCustomCurrencyShow(void);

bool OpenRCT2MacNativeCustomCurrencyPresent(void)
{
    return OpenRCT2MacNativeCustomCurrencyShow();
}

int32_t OpenRCT2MacNativeCustomCurrencyGetRate(void)
{
    return CurrencyDescriptors[EnumValue(CurrencyType::custom)].rate;
}

void OpenRCT2MacNativeCustomCurrencySetRate(int32_t rate)
{
    if (rate < 1)
        rate = 1;
    CurrencyDescriptors[EnumValue(CurrencyType::custom)].rate = static_cast<int16_t>(rate);
    Config::Get().general.customCurrencyRate = CurrencyDescriptors[EnumValue(CurrencyType::custom)].rate;
    Config::Save();
    OpenRCT2::Ui::GetWindowManager()->InvalidateAll();
}

void OpenRCT2MacNativeCustomCurrencyGetSymbol(char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    std::snprintf(out, outLen, "%s", CurrencyDescriptors[EnumValue(CurrencyType::custom)].symbol_unicode);
}

void OpenRCT2MacNativeCustomCurrencySetSymbol(const char* symbol)
{
    if (symbol == nullptr)
        return;
    auto& desc = CurrencyDescriptors[EnumValue(CurrencyType::custom)];
    std::snprintf(desc.symbol_unicode, sizeof(desc.symbol_unicode), "%s", symbol);
    Config::Get().general.customCurrencySymbol = symbol;
    Config::Save();
    OpenRCT2::Ui::GetWindowManager()->InvalidateAll();
}

int32_t OpenRCT2MacNativeCustomCurrencyGetAffix(void)
{
    return CurrencyDescriptors[EnumValue(CurrencyType::custom)].affix_unicode == CurrencyAffix::prefix ? 0 : 1;
}

void OpenRCT2MacNativeCustomCurrencySetAffix(int32_t affix)
{
    const auto value = affix == 0 ? CurrencyAffix::prefix : CurrencyAffix::suffix;
    CurrencyDescriptors[EnumValue(CurrencyType::custom)].affix_unicode = value;
    Config::Get().general.customCurrencyAffix = value;
    Config::Save();
    OpenRCT2::Ui::GetWindowManager()->InvalidateAll();
}

extern "C" bool OpenRCT2MacNativeChangelogShow(int32_t personality);
extern "C" bool OpenRCT2MacNativeProgressShow(const char* text);
extern "C" void OpenRCT2MacNativeProgressSetUI(uint32_t current, uint32_t total);
extern "C" void OpenRCT2MacNativeProgressCloseUI(void);
extern "C" bool OpenRCT2MacNativeNetworkStatusShow(const char* text);
extern "C" void OpenRCT2MacNativeNetworkStatusCloseUI(void);
extern "C" bool OpenRCT2MacNativeViewClippingShow(void);
extern "C" bool OpenRCT2MacNativeAssetPacksShow(void);

extern "C" bool OpenRCT2MacNativeChangelogGetText(int32_t personality, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return false;
    out[0] = '\0';

    auto& env = GetContext()->GetPlatformEnvironment();
    std::string text;
    switch (personality)
    {
        case 1: // contributors
            text = File::ReadAllText(env.GetFilePath(PathId::contributors));
            break;
        case 2: // new version
            if (!GetContext()->HasNewVersionInfo())
                return false;
            {
                const auto* info = GetContext()->GetNewVersionInfo();
                text = info != nullptr ? info->changelog : "";
            }
            break;
        default: // changelog
            text = File::ReadAllText(env.GetFilePath(PathId::changelog));
            break;
    }
    std::snprintf(out, outLen, "%s", text.c_str());
    return true;
}

bool OpenRCT2MacNativeChangelogPresent(int32_t personality)
{
    return OpenRCT2MacNativeChangelogShow(personality);
}

static bool gMacNativeProgressActive = false;
static bool gMacNativeNetworkStatusActive = false;

static bool MacNativeIsMainThread()
{
    return pthread_main_np() != 0;
}

bool OpenRCT2MacNativeProgressPresent(const char* text)
{
    // Progress often opens from JobPool workers during load — MainActor.assumeIsolated
    // would SIGTRAP. Keep classic engine window off the main thread.
    if (!MacNativeIsMainThread())
        return false;
    OpenRCT2MacNativeNetworkStatusClose();
    gMacNativeProgressActive = OpenRCT2MacNativeProgressShow(text != nullptr ? text : "");
    return gMacNativeProgressActive;
}

void OpenRCT2MacNativeProgressSet(uint32_t current, uint32_t total)
{
    if (!gMacNativeProgressActive)
        return;
    OpenRCT2MacNativeProgressSetUI(current, total);
}

void OpenRCT2MacNativeProgressClose(void)
{
    if (!gMacNativeProgressActive)
        return;
    OpenRCT2MacNativeProgressCloseUI();
    gMacNativeProgressActive = false;
}

bool OpenRCT2MacNativeNetworkStatusPresent(const char* text)
{
    if (!MacNativeIsMainThread())
        return false;
    OpenRCT2MacNativeProgressClose();
    gMacNativeNetworkStatusActive = OpenRCT2MacNativeNetworkStatusShow(text != nullptr ? text : "");
    return gMacNativeNetworkStatusActive;
}

void OpenRCT2MacNativeNetworkStatusClose(void)
{
    if (!gMacNativeNetworkStatusActive)
        return;
    OpenRCT2MacNativeNetworkStatusCloseUI();
    gMacNativeNetworkStatusActive = false;
}

bool OpenRCT2MacNativeViewClippingPresent(void)
{
    return OpenRCT2MacNativeViewClippingShow();
}

bool OpenRCT2MacNativeViewClippingGetEnabled(void)
{
    auto* w = WindowGetMain();
    return w != nullptr && w->viewport != nullptr && (w->viewport->flags & VIEWPORT_FLAG_CLIP_VIEW);
}

void OpenRCT2MacNativeViewClippingSetEnabled(bool enabled)
{
    auto* w = WindowGetMain();
    if (w == nullptr || w->viewport == nullptr)
        return;
    if (enabled)
        w->viewport->flags |= VIEWPORT_FLAG_CLIP_VIEW;
    else
        w->viewport->flags &= ~VIEWPORT_FLAG_CLIP_VIEW;
    w->invalidate();
}

bool OpenRCT2MacNativeViewClippingGetSeeThrough(void)
{
    auto* w = WindowGetMain();
    return w != nullptr && w->viewport != nullptr && (w->viewport->flags & VIEWPORT_FLAG_CLIP_VIEW_SEE_THROUGH);
}

void OpenRCT2MacNativeViewClippingSetSeeThrough(bool enabled)
{
    auto* w = WindowGetMain();
    if (w == nullptr || w->viewport == nullptr)
        return;
    if (enabled)
        w->viewport->flags |= VIEWPORT_FLAG_CLIP_VIEW_SEE_THROUGH;
    else
        w->viewport->flags &= ~VIEWPORT_FLAG_CLIP_VIEW_SEE_THROUGH;
    w->invalidate();
}

int32_t OpenRCT2MacNativeViewClippingGetHeight(void)
{
    return gClipHeight;
}

void OpenRCT2MacNativeViewClippingSetHeight(int32_t height)
{
    if (height < 0)
        height = 0;
    if (height > 255)
        height = 255;
    gClipHeight = static_cast<uint8_t>(height);
    if (auto* w = WindowGetMain(); w != nullptr)
        w->invalidate();
}

void OpenRCT2MacNativeViewClippingClearSelection(void)
{
    gClipSelectionA = { 0, 0 };
    gClipSelectionB = { kMaximumMapSizeBig - 1, kMaximumMapSizeBig - 1 };
    GfxInvalidateScreen();
}

bool OpenRCT2MacNativeAssetPacksPresent(void)
{
    return OpenRCT2MacNativeAssetPacksShow();
}

int32_t OpenRCT2MacNativeAssetPackCount(void)
{
    auto* mgr = GetContext()->GetAssetPackManager();
    return mgr != nullptr ? static_cast<int32_t>(mgr->GetCount()) : 0;
}

void OpenRCT2MacNativeAssetPackGetName(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    auto* mgr = GetContext()->GetAssetPackManager();
    if (mgr == nullptr)
        return;
    auto* pack = mgr->GetAssetPack(static_cast<size_t>(index));
    if (pack == nullptr)
        return;
    std::snprintf(out, outLen, "%s", pack->Name.c_str());
}

bool OpenRCT2MacNativeAssetPackGetEnabled(int32_t index)
{
    auto* mgr = GetContext()->GetAssetPackManager();
    if (mgr == nullptr)
        return false;
    auto* pack = mgr->GetAssetPack(static_cast<size_t>(index));
    return pack != nullptr && pack->IsEnabled();
}

void OpenRCT2MacNativeAssetPackSetEnabled(int32_t index, bool enabled)
{
    auto* mgr = GetContext()->GetAssetPackManager();
    if (mgr == nullptr)
        return;
    auto* pack = mgr->GetAssetPack(static_cast<size_t>(index));
    if (pack != nullptr)
        pack->SetEnabled(enabled);
}

void OpenRCT2MacNativeAssetPackMove(int32_t index, int32_t direction)
{
    auto* mgr = GetContext()->GetAssetPackManager();
    if (mgr == nullptr || index < 0)
        return;
    const auto count = static_cast<int32_t>(mgr->GetCount());
    if (direction < 0 && index > 0)
        mgr->Swap(static_cast<size_t>(index), static_cast<size_t>(index - 1));
    else if (direction > 0 && index < count - 1)
        mgr->Swap(static_cast<size_t>(index), static_cast<size_t>(index + 1));
}

void OpenRCT2MacNativeAssetPackApply(void)
{
    auto& objectManager = GetContext()->GetObjectManager();
    objectManager.ResetObjects();
    if (auto* mgr = GetContext()->GetAssetPackManager(); mgr != nullptr)
        mgr->SaveEnabledAssetPacks();
}

extern "C" bool OpenRCT2MacNativeOptionsShow(void);
extern "C" bool OpenRCT2MacNativeCheatsShow(void);

bool OpenRCT2MacNativeOptionsPresent(void)
{
    return OpenRCT2MacNativeOptionsShow();
}

bool OpenRCT2MacNativeCheatsPresent(void)
{
    return OpenRCT2MacNativeCheatsShow();
}

enum MacConfigBoolKey : int32_t
{
    MacConfig_UncapFPS = 0,
    MacConfig_UseVSync = 1,
    MacConfig_ShowFPS = 2,
    MacConfig_LandscapeSmoothing = 3,
    MacConfig_AlwaysShowGridlines = 4,
    MacConfig_DayNightCycle = 5,
    MacConfig_EnableLightFx = 6,
    MacConfig_RenderWeatherEffects = 7,
    MacConfig_RenderWeatherGloom = 8,
    MacConfig_TransparentWater = 9,
    MacConfig_ShowGuestPurchases = 10,
    MacConfig_EdgeScrolling = 11,
    MacConfig_InvertViewportDrag = 12,
    MacConfig_ZoomToCursor = 13,
    MacConfig_TrapCursor = 14,
    MacConfig_ToolbarShowFinances = 15,
    MacConfig_ToolbarShowResearch = 16,
    MacConfig_ToolbarShowCheats = 17,
    MacConfig_ToolbarShowNews = 18,
    MacConfig_ToolbarShowMute = 19,
    MacConfig_ToolbarShowChat = 20,
    MacConfig_ToolbarShowZoom = 21,
    MacConfig_MasterSoundEnabled = 22,
    MacConfig_SoundEnabled = 23,
    MacConfig_RideMusicEnabled = 24,
    MacConfig_AudioFocus = 25,
    MacConfig_DebuggingTools = 26,
    MacConfig_AutoStaffPlacement = 27,
    MacConfig_AutoOpenShops = 28,
    MacConfig_ShowRealNamesOfGuests = 29,
    MacConfig_ShowRealNamesOfStaff = 30,
    MacConfig_ConfirmationPrompt = 31,
    MacConfig_AllowEarlyCompletion = 32,
};

static bool* MacConfigBoolPtr(int32_t key)
{
    auto& cfg = Config::Get();
    switch (key)
    {
        case MacConfig_UncapFPS:
            return &cfg.general.uncapFPS;
        case MacConfig_UseVSync:
            return &cfg.general.useVSync;
        case MacConfig_ShowFPS:
            return &cfg.general.showFPS;
        case MacConfig_LandscapeSmoothing:
            return &cfg.general.landscapeSmoothing;
        case MacConfig_AlwaysShowGridlines:
            return &cfg.general.alwaysShowGridlines;
        case MacConfig_DayNightCycle:
            return &cfg.general.dayNightCycle;
        case MacConfig_EnableLightFx:
            return &cfg.general.enableLightFx;
        case MacConfig_RenderWeatherEffects:
            return &cfg.general.renderWeatherEffects;
        case MacConfig_RenderWeatherGloom:
            return &cfg.general.renderWeatherGloom;
        case MacConfig_TransparentWater:
            return &cfg.general.transparentWater;
        case MacConfig_ShowGuestPurchases:
            return &cfg.general.showGuestPurchases;
        case MacConfig_EdgeScrolling:
            return &cfg.general.edgeScrolling;
        case MacConfig_InvertViewportDrag:
            return &cfg.general.invertViewportDrag;
        case MacConfig_ZoomToCursor:
            return &cfg.general.zoomToCursor;
        case MacConfig_TrapCursor:
            return &cfg.general.trapCursor;
        case MacConfig_ToolbarShowFinances:
            return &cfg.interface.toolbarShowFinances;
        case MacConfig_ToolbarShowResearch:
            return &cfg.interface.toolbarShowResearch;
        case MacConfig_ToolbarShowCheats:
            return &cfg.interface.toolbarShowCheats;
        case MacConfig_ToolbarShowNews:
            return &cfg.interface.toolbarShowNews;
        case MacConfig_ToolbarShowMute:
            return &cfg.interface.toolbarShowMute;
        case MacConfig_ToolbarShowChat:
            return &cfg.interface.toolbarShowChat;
        case MacConfig_ToolbarShowZoom:
            return &cfg.interface.toolbarShowZoom;
        case MacConfig_MasterSoundEnabled:
            return &cfg.sound.masterSoundEnabled;
        case MacConfig_SoundEnabled:
            return &cfg.sound.soundEnabled;
        case MacConfig_RideMusicEnabled:
            return &cfg.sound.rideMusicEnabled;
        case MacConfig_AudioFocus:
            return &cfg.sound.audioFocus;
        case MacConfig_DebuggingTools:
            return &cfg.general.debuggingTools;
        case MacConfig_AutoStaffPlacement:
            return &cfg.general.autoStaffPlacement;
        case MacConfig_AutoOpenShops:
            return &cfg.general.autoOpenShops;
        case MacConfig_ShowRealNamesOfGuests:
            return &cfg.general.showRealNamesOfGuests;
        case MacConfig_ShowRealNamesOfStaff:
            return &cfg.general.showRealNamesOfStaff;
        case MacConfig_ConfirmationPrompt:
            return &cfg.general.confirmationPrompt;
        case MacConfig_AllowEarlyCompletion:
            return &cfg.general.allowEarlyCompletion;
        default:
            return nullptr;
    }
}

bool OpenRCT2MacNativeConfigGetBool(int32_t key)
{
    if (auto* p = MacConfigBoolPtr(key); p != nullptr)
        return *p;
    return false;
}

void OpenRCT2MacNativeConfigSetBool(int32_t key, bool value)
{
    if (auto* p = MacConfigBoolPtr(key); p != nullptr)
        *p = value;
}

void OpenRCT2MacNativeConfigSave(void)
{
    Config::Save();
}

static bool MacCheatStateGet(CheatType type)
{
    const auto& c = getGameState().cheats;
    switch (type)
    {
        case CheatType::sandboxMode:
            return c.sandboxMode;
        case CheatType::disableClearanceChecks:
            return c.disableClearanceChecks;
        case CheatType::disableSupportLimits:
            return c.disableSupportLimits;
        case CheatType::showAllOperatingModes:
            return c.showAllOperatingModes;
        case CheatType::showVehiclesFromOtherTrackTypes:
            return c.showVehiclesFromOtherTrackTypes;
        case CheatType::disableTrainLengthLimit:
            return c.disableTrainLengthLimit;
        case CheatType::enableChainLiftOnAllTrack:
            return c.enableChainLiftOnAllTrack;
        case CheatType::disableBrakesFailure:
            return c.disableBrakesFailure;
        case CheatType::disableAllBreakdowns:
            return c.disableAllBreakdowns;
        case CheatType::buildInPauseMode:
            return c.buildInPauseMode;
        case CheatType::ignoreRideIntensity:
            return c.ignoreRideIntensity;
        case CheatType::disableVandalism:
            return c.disableVandalism;
        case CheatType::disableLittering:
            return c.disableLittering;
        case CheatType::noMoney:
            return getGameState().park.flags.has(ParkFlag::noMoney);
        case CheatType::freezeWeather:
            return c.freezeWeather;
        case CheatType::neverendingMarketing:
            return c.neverendingMarketing;
        case CheatType::allowArbitraryRideTypeChanges:
            return c.allowArbitraryRideTypeChanges;
        case CheatType::disableRideValueAging:
            return c.disableRideValueAging;
        case CheatType::ignoreResearchStatus:
            return c.ignoreResearchStatus;
        case CheatType::enableAllDrawableTrackPieces:
            return c.enableAllDrawableTrackPieces;
        case CheatType::allowTrackPlaceInvalidHeights:
            return c.allowTrackPlaceInvalidHeights;
        case CheatType::allowRegularPathAsQueue:
            return c.allowRegularPathAsQueue;
        case CheatType::allowSpecialColourSchemes:
            return c.allowSpecialColourSchemes;
        case CheatType::ignorePrice:
            return c.ignorePrice;
        case CheatType::disableGrassGrowing:
            return c.disableGrassGrowing;
        case CheatType::disablePlantAging:
            return c.disablePlantAging;
        case CheatType::makeDestructible:
            return c.makeAllDestructible;
        default:
            return false;
    }
}

bool OpenRCT2MacNativeCheatGet(int32_t type)
{
    return MacCheatStateGet(static_cast<CheatType>(type));
}

void OpenRCT2MacNativeCheatToggle(int32_t type)
{
    const auto cheat = static_cast<CheatType>(type);
    if (cheat == CheatType::noMoney)
    {
        CheatsSet(CheatType::noMoney, getGameState().park.flags.has(ParkFlag::noMoney) ? 0 : 1);
        return;
    }
    CheatsSet(cheat);
}

void OpenRCT2MacNativeCheatRun(int32_t type, int64_t p1, int64_t p2)
{
    CheatsSet(static_cast<CheatType>(type), p1, p2);
}

extern "C" bool OpenRCT2MacNativeObjectLoadErrorShow(const char* path, const char* rows);
extern "C" bool OpenRCT2MacNativeShortcutKeysShow(void);
extern "C" bool OpenRCT2MacNativeShortcutChangeShow(const char* id);

bool OpenRCT2MacNativeObjectLoadErrorPresent(const char* path, const char* rows)
{
    return OpenRCT2MacNativeObjectLoadErrorShow(path != nullptr ? path : "", rows != nullptr ? rows : "");
}

static std::vector<std::string> gMacShortcutIds;

static void MacShortcutRebuildIndex()
{
    gMacShortcutIds.clear();
    auto& mgr = GetShortcutManager();
    for (auto& pair : mgr.shortcuts)
    {
        gMacShortcutIds.emplace_back(pair.second.id);
    }
    std::sort(gMacShortcutIds.begin(), gMacShortcutIds.end());
}

bool OpenRCT2MacNativeShortcutKeysPresent(void)
{
    MacShortcutRebuildIndex();
    return OpenRCT2MacNativeShortcutKeysShow();
}

int32_t OpenRCT2MacNativeShortcutCount(void)
{
    if (gMacShortcutIds.empty())
        MacShortcutRebuildIndex();
    return static_cast<int32_t>(gMacShortcutIds.size());
}

void OpenRCT2MacNativeShortcutGetId(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacShortcutIds.size())
        return;
    std::snprintf(out, outLen, "%s", gMacShortcutIds[static_cast<size_t>(index)].c_str());
}

void OpenRCT2MacNativeShortcutGetName(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacShortcutIds.size())
        return;
    auto* sc = GetShortcutManager().getShortcut(gMacShortcutIds[static_cast<size_t>(index)]);
    if (sc == nullptr)
        return;
    if (sc->localisedName != kStringIdNone)
    {
        if (const char* s = LanguageGetString(sc->localisedName); s != nullptr)
        {
            std::snprintf(out, outLen, "%s", s);
            return;
        }
    }
    std::snprintf(out, outLen, "%s", sc->customName.c_str());
}

void OpenRCT2MacNativeShortcutGetChord(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacShortcutIds.size())
        return;
    auto* sc = GetShortcutManager().getShortcut(gMacShortcutIds[static_cast<size_t>(index)]);
    if (sc == nullptr || sc->current.empty())
        return;
    std::snprintf(out, outLen, "%s", sc->current[0].toString().c_str());
}

void OpenRCT2MacNativeShortcutRemove(const char* id)
{
    if (id == nullptr)
        return;
    auto* sc = GetShortcutManager().getShortcut(id);
    if (sc == nullptr)
        return;
    sc->current.clear();
    GetShortcutManager().saveUserBindings();
}

void OpenRCT2MacNativeShortcutResetAll(void)
{
    auto& mgr = GetShortcutManager();
    for (auto& pair : mgr.shortcuts)
    {
        pair.second.current = pair.second.standard;
    }
    mgr.saveUserBindings();
    MacShortcutRebuildIndex();
}

bool OpenRCT2MacNativeShortcutChangePresent(const char* id)
{
    return OpenRCT2MacNativeShortcutChangeShow(id);
}

extern "C" void OpenRCT2MacNativeShortcutApplyChord(const char* id, const char* chord)
{
    if (id == nullptr)
        return;
    auto* sc = GetShortcutManager().getShortcut(id);
    if (sc == nullptr)
        return;
    if (chord == nullptr || chord[0] == '\0')
    {
        sc->current.clear();
    }
    else
    {
        sc->current = { ShortcutInput(chord) };
    }
    GetShortcutManager().saveUserBindings();
}

extern "C" bool OpenRCT2MacNativeThemesShow(void);
extern "C" bool OpenRCT2MacNativeNewCampaignShow(int16_t type);

bool OpenRCT2MacNativeThemesPresent(void)
{
    return OpenRCT2MacNativeThemesShow();
}

int32_t OpenRCT2MacNativeThemeCount(void)
{
    return static_cast<int32_t>(ThemeManagerGetNumAvailableThemes());
}

void OpenRCT2MacNativeThemeGetName(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= ThemeManagerGetNumAvailableThemes())
        return;
    if (const utf8* name = ThemeManagerGetAvailableThemeName(static_cast<size_t>(index)); name != nullptr)
        std::snprintf(out, outLen, "%s", name);
}

int32_t OpenRCT2MacNativeThemeGetActive(void)
{
    return static_cast<int32_t>(ThemeManagerGetAvailableThemeIndex());
}

void OpenRCT2MacNativeThemeSetActive(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= ThemeManagerGetNumAvailableThemes())
        return;
    ThemeManagerSetActiveAvailableTheme(static_cast<size_t>(index));
}

uint8_t OpenRCT2MacNativeThemeGetFlags(void)
{
    return ThemeGetFlags();
}

void OpenRCT2MacNativeThemeToggleFlag(uint8_t flag)
{
    ThemeSetFlags(ThemeGetFlags() ^ flag);
    ThemeSave();
    ColourSchemeUpdateAll();
}

static std::vector<RideId> gMacCampaignRides;
static std::vector<ShopItem> gMacCampaignShops;
static int16_t gMacCampaignType = -1;

static void MacCampaignRebuildTargets(int16_t campaignType)
{
    gMacCampaignType = campaignType;
    gMacCampaignRides.clear();
    gMacCampaignShops.clear();
    const auto& gameState = getGameState();
    if (campaignType == ADVERTISING_CAMPAIGN_FOOD_OR_DRINK_FREE)
    {
        OpenRCT2::BitSet<EnumValue(ShopItem::count)> items = {};
        for (auto& curRide : RideManager(gameState))
        {
            auto* rideEntry = curRide.getRideEntry();
            if (rideEntry != nullptr && curRide.status == RideStatus::open)
            {
                for (const auto itemType : rideEntry->shop_item)
                {
                    if (itemType != ShopItem::none && GetShopItemDescriptor(itemType).IsFoodOrDrink())
                        items[EnumValue(itemType)] = true;
                }
            }
        }
        for (auto i = 0; i < EnumValue(ShopItem::count); i++)
        {
            if (items[i])
                gMacCampaignShops.push_back(static_cast<ShopItem>(i));
        }
        return;
    }

    for (const auto& curRide : RideManager(gameState))
    {
        if (curRide.status != RideStatus::open)
            continue;
        const auto& rtd = curRide.getRideTypeDescriptor();
        if (rtd.flags.has(RtdFlag::isShopOrFacility) || rtd.flags.has(RtdFlag::sellsFood) || rtd.flags.has(RtdFlag::sellsDrinks)
            || rtd.specialType == RtdSpecialType::toilet)
            continue;
        gMacCampaignRides.push_back(curRide.id);
    }
}

bool OpenRCT2MacNativeNewCampaignPresent(int16_t campaignType)
{
    MacCampaignRebuildTargets(campaignType);
    return OpenRCT2MacNativeNewCampaignShow(campaignType);
}

int32_t OpenRCT2MacNativeCampaignRideCount(int16_t campaignType)
{
    if (gMacCampaignType != campaignType)
        MacCampaignRebuildTargets(campaignType);
    if (campaignType == ADVERTISING_CAMPAIGN_FOOD_OR_DRINK_FREE)
        return static_cast<int32_t>(gMacCampaignShops.size());
    // Park-wide campaigns need no target.
    if (campaignType == ADVERTISING_CAMPAIGN_PARK_ENTRY_FREE || campaignType == ADVERTISING_CAMPAIGN_PARK_ENTRY_HALF_PRICE
        || campaignType == ADVERTISING_CAMPAIGN_PARK)
        return 0;
    return static_cast<int32_t>(gMacCampaignRides.size());
}

void OpenRCT2MacNativeCampaignRideName(int16_t campaignType, int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (gMacCampaignType != campaignType)
        MacCampaignRebuildTargets(campaignType);
    if (campaignType == ADVERTISING_CAMPAIGN_FOOD_OR_DRINK_FREE)
    {
        if (index < 0 || static_cast<size_t>(index) >= gMacCampaignShops.size())
            return;
        const auto& naming = GetShopItemDescriptor(gMacCampaignShops[static_cast<size_t>(index)]).Naming;
        if (const char* s = LanguageGetString(naming.Plural); s != nullptr)
            std::snprintf(out, outLen, "%s", s);
        return;
    }
    if (index < 0 || static_cast<size_t>(index) >= gMacCampaignRides.size())
        return;
    if (auto* ride = GetRide(gMacCampaignRides[static_cast<size_t>(index)]); ride != nullptr)
        std::snprintf(out, outLen, "%s", ride->getName().c_str());
}

void OpenRCT2MacNativeCampaignStart(int16_t campaignType, int32_t rideIndex, int32_t weeks)
{
    if (weeks < 2)
        weeks = 2;
    if (weeks > 12)
        weeks = 12;
    if (gMacCampaignType != campaignType)
        MacCampaignRebuildTargets(campaignType);

    uint16_t rideOrItem = 0;
    if (campaignType == ADVERTISING_CAMPAIGN_FOOD_OR_DRINK_FREE)
    {
        if (rideIndex < 0 || static_cast<size_t>(rideIndex) >= gMacCampaignShops.size())
            return;
        rideOrItem = static_cast<uint16_t>(EnumValue(gMacCampaignShops[static_cast<size_t>(rideIndex)]));
    }
    else if (
        campaignType != ADVERTISING_CAMPAIGN_PARK_ENTRY_FREE && campaignType != ADVERTISING_CAMPAIGN_PARK_ENTRY_HALF_PRICE
        && campaignType != ADVERTISING_CAMPAIGN_PARK)
    {
        if (rideIndex < 0 || static_cast<size_t>(rideIndex) >= gMacCampaignRides.size())
            return;
        rideOrItem = gMacCampaignRides[static_cast<size_t>(rideIndex)].ToUnderlying();
    }

    auto gameAction = GameActions::ParkMarketingAction(campaignType, rideOrItem, weeks);
    GameActions::Execute(&gameAction, getGameState());
}

// ---------------------------------------------------------------------------
// Title browsers: scenario select + load park (Liquid Glass)
// ---------------------------------------------------------------------------

#include <openrct2-ui/UiStringIds.h>
#include <openrct2-ui/interface/FileBrowser.h>
#include <openrct2-ui/interface/Objective.h>
#include <openrct2/Diagnostic.h>
#include <openrct2/FileClassifier.h>
#include <openrct2/ParkImporter.h>
#include <openrct2/core/BackgroundWorker.hpp>
#include <openrct2/core/FileScanner.h>
#include <openrct2/core/FileStream.h>
#include <openrct2/core/Path.hpp>
#include <openrct2/drawing/Drawing.h>
#include <openrct2/localisation/Formatting.h>
#include <openrct2/object/ObjectManager.h>
#include <openrct2/object/ScenarioMetaObject.h>
#include <openrct2/park/ParkPreview.h>
#include <openrct2/platform/Platform.h>
#include <openrct2/rct12/RCT12.h>
#include <openrct2/scenario/ScenarioCategory.h>
#include <openrct2/scenario/ScenarioObjective.h>
#include <openrct2/scenario/ScenarioRepository.h>
#include <openrct2/scenario/ScenarioSources.h>
#include <functional>
#include <optional>

extern "C" bool OpenRCT2MacNativeScenarioSelectShow(void);
extern "C" bool OpenRCT2MacNativeLoadParkShow(void);
extern "C" void OpenRCT2MacNativeScenarioPreviewLoading(int32_t row);
extern "C" void OpenRCT2MacNativeScenarioPreviewReady(int32_t row, const uint8_t* rgba, int32_t width, int32_t height);

namespace
{
    constexpr int32_t kMacScenarioTabCount = 10;
    constexpr int32_t kMacInitialUnlocked = 5;

    constexpr StringId kMacScenarioOriginStringIds[] = {
        STR_SCENARIO_CATEGORY_RCT1,        STR_SCENARIO_CATEGORY_RCT1_AA,    STR_SCENARIO_CATEGORY_RCT1_LL,
        STR_SCENARIO_CATEGORY_RCT2,        STR_SCENARIO_CATEGORY_RCT2_WW,    STR_SCENARIO_CATEGORY_RCT2_TT,
        STR_SCENARIO_CATEGORY_UCES,        STR_SCENARIO_CATEGORY_REAL_PARKS, STR_SCENARIO_CATEGORY_EXTRAS_PARKS,
        STR_SCENARIO_CATEGORY_OTHER_PARKS,
    };

    enum class MacScenarioRowKind : int32_t
    {
        heading = 0,
        scenario = 1,
    };

    struct MacScenarioRow
    {
        MacScenarioRowKind kind{};
        std::string name;
        std::string details;
        std::string path;
        std::string internalName;
        bool locked{};
    };

    struct MacSaveFileRow
    {
        std::string name;
        std::string path;
        std::string date;
        time_t modified{};
    };

    std::function<void(std::string_view)> gMacScenarioCallback;
    int32_t gMacScenarioActiveTab = 0;
    uint32_t gMacScenarioVisibleTabs = 0;
    std::vector<MacScenarioRow> gMacScenarioRows;
    BackgroundWorker::Job gMacPreviewJob;
    int32_t gMacPreviewRow = -1;

    std::vector<MacSaveFileRow> gMacSaveFiles;

    std::string MacPlain(std::string_view text)
    {
        return RCT12RemoveFormattingUTF8(text);
    }

    std::string MacStringId(StringId id)
    {
        if (const char* s = LanguageGetString(id); s != nullptr)
            return MacPlain(s);
        return {};
    }

    std::string MacScenarioObjective(const ScenarioIndexEntry& scenario)
    {
        const auto objectiveIndex = EnumValue(scenario.ObjectiveType);
        if (objectiveIndex >= static_cast<int32_t>(std::size(kObjectiveNames)))
            return {};
        Scenario::Objective objective = {
            .Type = scenario.ObjectiveType,
            .Year = scenario.ObjectiveArg1,
            .NumGuests = static_cast<uint16_t>(scenario.ObjectiveArg3),
            .Currency = scenario.ObjectiveArg2,
        };
        Formatter ft;
        formatObjective(ft, objective);
        return MacPlain(FormatStringIDLegacy(kObjectiveNames[objectiveIndex], ft.Data()));
    }

    void MacScenarioRebuildTabs()
    {
        gMacScenarioVisibleTabs = 0;
        const size_t count = ScenarioRepositoryGetCount();
        for (size_t i = 0; i < count; i++)
        {
            if (const auto* sc = ScenarioRepositoryGetByIndex(i); sc != nullptr)
                gMacScenarioVisibleTabs |= 1u << static_cast<uint8_t>(sc->SourceGame);
        }
        if (gMacScenarioVisibleTabs & (1u << Config::Get().interface.scenarioSelectLastTab))
            gMacScenarioActiveTab = Config::Get().interface.scenarioSelectLastTab;
        else
        {
            for (int32_t i = 0; i < kMacScenarioTabCount; i++)
            {
                if (gMacScenarioVisibleTabs & (1u << i))
                {
                    gMacScenarioActiveTab = i;
                    break;
                }
            }
        }
    }

    bool MacScenarioLockingEnabled()
    {
        return Config::Get().general.scenarioUnlockingEnabled && gMacScenarioActiveTab < 6;
    }

    void MacScenarioRebuildRows()
    {
        gMacScenarioRows.clear();
        const size_t count = ScenarioRepositoryGetCount();
        int32_t numUnlocks = kMacInitialUnlocked;
        const uint32_t rct1Required = (1u << SC_MEGA_PARK) - 1;
        uint32_t rct1Completed = 0;
        std::optional<size_t> megaIdx;
        std::optional<Scenario::Category> currentHeading;

        for (size_t i = 0; i < count; i++)
        {
            const ScenarioIndexEntry* scenario = ScenarioRepositoryGetByIndex(i);
            if (scenario == nullptr || static_cast<uint8_t>(scenario->SourceGame) != gMacScenarioActiveTab)
                continue;

            if (gMacScenarioActiveTab != EnumValue(ScenarioSource::real)
                && (!currentHeading.has_value() || currentHeading.value() != scenario->Category))
            {
                currentHeading = scenario->Category;
                MacScenarioRow header;
                header.kind = MacScenarioRowKind::heading;
                header.name = MacStringId(Scenario::kScenarioCategoryStringIds[EnumValue(scenario->Category)]);
                gMacScenarioRows.push_back(std::move(header));
            }

            MacScenarioRow row;
            row.kind = MacScenarioRowKind::scenario;
            row.name = scenario->Name.empty() ? scenario->InternalName : scenario->Name;
            row.details = MacScenarioObjective(*scenario);
            if (!scenario->Details.empty())
            {
                if (!row.details.empty())
                    row.details += "\n";
                row.details += MacPlain(scenario->Details);
            }
            row.path = scenario->Path;
            row.internalName = scenario->InternalName;
            if (MacScenarioLockingEnabled())
            {
                row.locked = numUnlocks <= 0;
                if (scenario->Highscore == nullptr)
                    numUnlocks--;
                else if (scenario->ScenarioId < SC_MEGA_PARK)
                    rct1Completed |= 1u << scenario->ScenarioId;
                if (scenario->ScenarioId == SC_MEGA_PARK)
                    megaIdx = gMacScenarioRows.size();
            }
            gMacScenarioRows.push_back(std::move(row));
        }

        if (megaIdx.has_value() && megaIdx.value() < gMacScenarioRows.size())
        {
            const bool megaLocked = (rct1Completed & rct1Required) != rct1Required;
            gMacScenarioRows[*megaIdx].locked = megaLocked;
            if (megaLocked && Config::Get().general.scenarioHideMegaPark)
                gMacScenarioRows.erase(gMacScenarioRows.begin() + static_cast<std::ptrdiff_t>(*megaIdx));
        }
    }

    void MacSaveRebuildList()
    {
        gMacSaveFiles.clear();
        const auto dir = FileBrowser::GetDir(LoadSaveType::park);
        if (dir.empty() || !Path::DirectoryExists(dir))
            return;

        const auto pattern = Path::Combine(dir, "*.park");
        auto scanner = Path::ScanDirectory(pattern, false);
        while (scanner->Next())
        {
            MacSaveFileRow row;
            row.path = scanner->GetPath();
            row.name = Path::GetFileNameWithoutExtension(row.path);
            row.modified = Platform::FileGetModifiedTime(row.path.c_str());
            row.date = Platform::FormatShortDate(row.modified) + " " + Platform::FormatTime(row.modified);
            gMacSaveFiles.push_back(std::move(row));
        }

        std::sort(gMacSaveFiles.begin(), gMacSaveFiles.end(), [](const MacSaveFileRow& a, const MacSaveFileRow& b) {
            return a.modified > b.modified;
        });
    }
} // namespace

bool OpenRCT2MacNativeScenarioSelectPresent(void)
{
    if (!MacNativeIsMainThread())
        return false;
    ScenarioRepositoryScan();
    MacScenarioRebuildTabs();
    MacScenarioRebuildRows();
    return OpenRCT2MacNativeScenarioSelectShow();
}

bool OpenRCT2::Ui::MacNativeScenarioSelectOpen(std::function<void(std::string_view)> callback)
{
    gMacScenarioCallback = std::move(callback);
    return OpenRCT2MacNativeScenarioSelectPresent();
}

extern "C" int32_t OpenRCT2MacNativeScenarioTabCount(void)
{
    return kMacScenarioTabCount;
}

extern "C" bool OpenRCT2MacNativeScenarioTabVisible(int32_t tab)
{
    if (tab < 0 || tab >= kMacScenarioTabCount)
        return false;
    return (gMacScenarioVisibleTabs & (1u << tab)) != 0;
}

extern "C" void OpenRCT2MacNativeScenarioTabName(int32_t tab, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (tab < 0 || tab >= kMacScenarioTabCount)
        return;
    std::snprintf(out, outLen, "%s", MacStringId(kMacScenarioOriginStringIds[tab]).c_str());
}

extern "C" int32_t OpenRCT2MacNativeScenarioGetActiveTab(void)
{
    return gMacScenarioActiveTab;
}

extern "C" void OpenRCT2MacNativeScenarioSetActiveTab(int32_t tab)
{
    if (tab < 0 || tab >= kMacScenarioTabCount)
        return;
    if ((gMacScenarioVisibleTabs & (1u << tab)) == 0)
        return;
    gMacScenarioActiveTab = tab;
    Config::Get().interface.scenarioSelectLastTab = tab;
    Config::Save();
    MacScenarioRebuildRows();
}

extern "C" int32_t OpenRCT2MacNativeScenarioRowCount(void)
{
    return static_cast<int32_t>(gMacScenarioRows.size());
}

extern "C" int32_t OpenRCT2MacNativeScenarioRowKind(int32_t row)
{
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return 0;
    return static_cast<int32_t>(gMacScenarioRows[static_cast<size_t>(row)].kind);
}

extern "C" void OpenRCT2MacNativeScenarioRowName(int32_t row, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return;
    std::snprintf(out, outLen, "%s", gMacScenarioRows[static_cast<size_t>(row)].name.c_str());
}

extern "C" void OpenRCT2MacNativeScenarioRowDetails(int32_t row, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return;
    std::snprintf(out, outLen, "%s", gMacScenarioRows[static_cast<size_t>(row)].details.c_str());
}

extern "C" bool OpenRCT2MacNativeScenarioRowLocked(int32_t row)
{
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return true;
    return gMacScenarioRows[static_cast<size_t>(row)].locked;
}

extern "C" bool OpenRCT2MacNativeScenarioSelectRow(int32_t row)
{
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return false;
    const auto& item = gMacScenarioRows[static_cast<size_t>(row)];
    if (item.kind != MacScenarioRowKind::scenario || item.locked || item.path.empty())
        return false;
    if (gMacScenarioCallback)
        gMacScenarioCallback(item.path);
    return true;
}

namespace
{
    void MacPublishScenarioPreview(int32_t row, const ParkPreview& preview)
    {
        if (row != gMacPreviewRow)
            return;

        const auto targetType = Config::Get().interface.scenarioPreviewScreenshots ? PreviewImageType::screenshot
                                                                                   : PreviewImageType::miniMap;
        const PreviewImage* image = nullptr;
        for (const auto& candidate : preview.images)
        {
            if (candidate.type == targetType)
            {
                image = &candidate;
                break;
            }
        }
        if (image == nullptr || image->width == 0 || image->height == 0)
        {
            OpenRCT2MacNativeScenarioPreviewReady(row, nullptr, 0, 0);
            return;
        }

        const size_t pixelCount = static_cast<size_t>(image->width) * image->height;
        std::vector<uint8_t> rgba(pixelCount * 4);
        for (size_t index = 0; index < pixelCount; ++index)
        {
            const auto paletteIndex = static_cast<uint8_t>(image->pixels[index]);
            const auto& colour = gPalette[paletteIndex];
            rgba[(index * 4) + 0] = colour.red;
            rgba[(index * 4) + 1] = colour.green;
            rgba[(index * 4) + 2] = colour.blue;
            rgba[(index * 4) + 3] = 0xFF;
        }
        OpenRCT2MacNativeScenarioPreviewReady(
            row, rgba.data(), static_cast<int32_t>(image->width), static_cast<int32_t>(image->height));
    }

    ParkPreview MacLoadMetadataPreview(const MacScenarioRow& entry)
    {
        SourceDescriptor source{};
        if (!ScenarioSources::TryGetByName(entry.internalName, &source))
            return {};

        auto& objectManager = GetContext()->GetObjectManager();
        auto object = objectManager.LoadTempObject(source.textObjectId, true);
        if (object == nullptr)
            return {};

        auto& scenarioMeta = reinterpret_cast<ScenarioMetaObject&>(*object);
        scenarioMeta.Load();
        ParkPreview preview{};
        preview.images.push_back(scenarioMeta.GetMiniMapImage());
        preview.images.push_back(scenarioMeta.GetPreviewImage());
        scenarioMeta.Unload();
        return preview;
    }
} // namespace

extern "C" void OpenRCT2MacNativeScenarioRequestPreview(int32_t row)
{
    if (row < 0 || static_cast<size_t>(row) >= gMacScenarioRows.size())
        return;
    const auto& entry = gMacScenarioRows[static_cast<size_t>(row)];
    if (entry.kind != MacScenarioRowKind::scenario || entry.locked)
        return;

    gMacPreviewRow = row;
    if (gMacPreviewJob.isValid())
        gMacPreviewJob.cancel();
    OpenRCT2MacNativeScenarioPreviewLoading(row);

    ClassifiedFileInfo info;
    if (TryClassifyFile(entry.path, &info) && info.Type == FileType::park)
    {
        const auto path = entry.path;
        auto& worker = GetContext()->GetBackgroundWorker();
        gMacPreviewJob = worker.addJob(
            [path]() {
                try
                {
                    auto stream = FileStream(path, FileMode::open);
                    auto& objectRepository = GetContext()->GetObjectRepository();
                    auto importer = ParkImporter::CreateParkFile(objectRepository);
                    importer->LoadFromStream(&stream, false, true, path.c_str());
                    return importer->GetParkPreview();
                }
                catch (const std::exception& error)
                {
                    LOG_ERROR(
                        "Could not get Mac scenario preview for \"%s\" due to %s", path.c_str(), error.what());
                    return ParkPreview{};
                }
            },
            [row](const ParkPreview preview) { MacPublishScenarioPreview(row, preview); });
        return;
    }

    MacPublishScenarioPreview(row, MacLoadMetadataPreview(entry));
}

bool OpenRCT2MacNativeLoadParkPresent(void)
{
    if (!MacNativeIsMainThread())
        return false;
    MacSaveRebuildList();
    return OpenRCT2MacNativeLoadParkShow();
}

bool OpenRCT2::Ui::MacNativeLoadParkOpen(
    std::function<void(OpenRCT2::ModalResult, std::string_view)> callback, bool isJsCallback)
{
    FileBrowser::RegisterCallback(std::move(callback), isJsCallback);
    return OpenRCT2MacNativeLoadParkPresent();
}

extern "C" void OpenRCT2MacNativeSaveFileRefresh(void)
{
    MacSaveRebuildList();
}

extern "C" int32_t OpenRCT2MacNativeSaveFileCount(void)
{
    return static_cast<int32_t>(gMacSaveFiles.size());
}

extern "C" void OpenRCT2MacNativeSaveFileGetName(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacSaveFiles.size())
        return;
    std::snprintf(out, outLen, "%s", gMacSaveFiles[static_cast<size_t>(index)].name.c_str());
}

extern "C" void OpenRCT2MacNativeSaveFileGetDate(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacSaveFiles.size())
        return;
    std::snprintf(out, outLen, "%s", gMacSaveFiles[static_cast<size_t>(index)].date.c_str());
}

extern "C" bool OpenRCT2MacNativeSaveFileLoad(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= gMacSaveFiles.size())
        return false;
    FileBrowser::Select(gMacSaveFiles[static_cast<size_t>(index)].path.c_str(), LoadSaveAction::load, LoadSaveType::park, nullptr);
    return true;
}

// ---------------------------------------------------------------------------
// Recent news (3.1)
// ---------------------------------------------------------------------------

#include <openrct2/localisation/Localisation.Date.h>
#include <openrct2/management/NewsItem.h>
#include <openrct2/ui/WindowManager.h>
#include <openrct2-ui/windows/Windows.h>

extern "C" bool OpenRCT2MacNativeRecentNewsShow(void);

namespace
{
    struct MacNewsRow
    {
        std::string date;
        std::string text;
        News::ItemType type{};
        uint32_t assoc{};
        bool hasSubject{};
        bool hasLocation{};
        bool hasButton{};
    };

    std::vector<MacNewsRow> gMacNewsRows;

    void MacNewsRebuild()
    {
        gMacNewsRows.clear();
        for (const auto& newsItem : getGameState().newsItems.getArchived())
        {
            MacNewsRow row;
            Formatter ft;
            if (newsItem.day >= 1 && newsItem.day <= 31)
            {
                ft.Add<StringId>(DateDayNames[newsItem.day - 1]);
                ft.Add<StringId>(DateGameMonthNames[DateGetMonth(newsItem.monthYear)]);
                row.date = MacPlain(FormatStringIDLegacy(STR_NEWS_DATE_FORMAT, ft.Data()));
            }
            row.text = MacPlain(newsItem.text);
            row.type = newsItem.type;
            row.assoc = newsItem.assoc;
            row.hasSubject = newsItem.typeHasSubject() && !newsItem.hasButton();
            row.hasLocation = newsItem.typeHasLocation() && !newsItem.hasButton();
            row.hasButton = newsItem.hasButton();
            gMacNewsRows.push_back(std::move(row));
        }
    }
} // namespace

bool OpenRCT2MacNativeRecentNewsPresent(void)
{
    if (!MacNativeIsMainThread())
        return false;
    MacNewsRebuild();
    return OpenRCT2MacNativeRecentNewsShow();
}

extern "C" void OpenRCT2MacNativeNewsRefresh(void)
{
    MacNewsRebuild();
}

extern "C" int32_t OpenRCT2MacNativeNewsCount(void)
{
    return static_cast<int32_t>(gMacNewsRows.size());
}

extern "C" void OpenRCT2MacNativeNewsGetDate(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return;
    std::snprintf(out, outLen, "%s", gMacNewsRows[static_cast<size_t>(index)].date.c_str());
}

extern "C" void OpenRCT2MacNativeNewsGetText(int32_t index, char* out, size_t outLen)
{
    if (out == nullptr || outLen == 0)
        return;
    out[0] = '\0';
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return;
    std::snprintf(out, outLen, "%s", gMacNewsRows[static_cast<size_t>(index)].text.c_str());
}

extern "C" bool OpenRCT2MacNativeNewsHasSubject(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return false;
    return gMacNewsRows[static_cast<size_t>(index)].hasSubject;
}

extern "C" bool OpenRCT2MacNativeNewsHasLocation(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return false;
    return gMacNewsRows[static_cast<size_t>(index)].hasLocation;
}

extern "C" void OpenRCT2MacNativeNewsOpenSubject(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return;
    const auto& row = gMacNewsRows[static_cast<size_t>(index)];
    if (!row.hasSubject)
        return;
    News::OpenSubject(row.type, static_cast<int32_t>(row.assoc));
}

extern "C" void OpenRCT2MacNativeNewsLocate(int32_t index)
{
    if (index < 0 || static_cast<size_t>(index) >= gMacNewsRows.size())
        return;
    const auto& row = gMacNewsRows[static_cast<size_t>(index)];
    if (!row.hasLocation)
        return;
    auto subjectLoc = News::GetSubjectLocation(row.type, static_cast<int32_t>(row.assoc));
    if (!subjectLoc.has_value())
        return;
    if (auto* mainWindow = WindowGetMain(); mainWindow != nullptr)
        WindowScrollToLocation(*mainWindow, subjectLoc.value());
}

#endif // TARGET_OS_OSX
