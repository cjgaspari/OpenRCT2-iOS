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
#include <openrct2/Context.h>
#include <openrct2/Game.h>
#include <openrct2/GameState.h>
#include <openrct2/OpenRCT2.h>
#include <openrct2/interface/Window.h>
#include <openrct2/ui/UiContext.h>
#include <openrct2/actions/GameActionRunner.h>
#include <openrct2/actions/ride/RideDemolishAction.h>
#include <openrct2/actions/peep/StaffFireAction.h>
#include <openrct2/audio/Audio.h>
#include <openrct2/config/Config.h>
#include <openrct2/core/EnumUtils.hpp>
#include <openrct2/drawing/Drawing.h>
#include <openrct2/entity/Peep.h>
#include <openrct2/localisation/Currency.h>
#include <openrct2/ui/WindowManager.h>
#include <openrct2/interface/Viewport.h>
#include <openrct2/network/Network.h>
#include <openrct2/paint/Paint.h>
#include <openrct2/paint/tile_element/Paint.TileElement.h>
#include <openrct2/ride/Ride.h>
#include <openrct2/ui/WindowManager.h>
#include <openrct2/windows/Intent.h>

#include <cstdio>
#include <memory>

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
    GetWindowManager()->InvalidateAll();
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
    GetWindowManager()->InvalidateAll();
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
    GetWindowManager()->InvalidateAll();
}

#endif // TARGET_OS_OSX
