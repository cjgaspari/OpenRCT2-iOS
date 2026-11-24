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
#include <openrct2/config/Config.h>
#include <openrct2/drawing/Drawing.h>
#include <openrct2/interface/Viewport.h>
#include <openrct2/paint/Paint.h>
#include <openrct2/paint/tile_element/Paint.TileElement.h>

#import <Foundation/Foundation.h>

using namespace OpenRCT2;

extern "C" bool OpenRCT2MacNativeDebugPaintShow(void);
extern "C" bool OpenRCT2MacNativeTransparencyShow(void);

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

#endif // TARGET_OS_OSX
