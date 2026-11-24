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
#include <openrct2/Cheats.h>
#include <openrct2/Context.h>
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
#include <openrct2/ride/Ride.h>
#include <openrct2/windows/Intent.h>
#include <openrct2/world/Map.h>
#include <openrct2/world/MapSelection.h>
#include <openrct2/world/Park.h>

#include <cstdio>
#include <memory>
#include <pthread.h>

#import <Foundation/Foundation.h>

using namespace OpenRCT2;
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

#endif // TARGET_OS_OSX
