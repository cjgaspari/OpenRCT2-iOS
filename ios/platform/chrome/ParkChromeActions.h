/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum
{
    kNativeChromeBuildNewRide = 1,
    kNativeChromeTrees = 2,
    kNativeChromePaths = 3,
    kNativeChromeLand = 4,
    kNativeChromeWater = 5,
    kNativeChromeClearScenery = 6,
    kNativeChromeRideList = 7,
    kNativeChromeParkInformation = 8,
    kNativeChromeStaffList = 9,
    kNativeChromeGuestList = 10,
    kNativeChromeFinances = 11,
    kNativeChromeResearch = 12,
    kNativeChromeRecentNews = 13,
    kNativeChromeMap = 14,
    kNativeChromeExtraViewport = 15,
    kNativeChromeViewClipping = 16,
    kNativeChromeTransparency = 17,
    kNativeChromeLoadSave = 18,
    kNativeChromeOptions = 19,
    kNativeChromeAbout = 20,
    kNativeChromeCheats = 21,
    kNativeChromeTileInspector = 22,
    kNativeChromePause = 23,
    kNativeChromeGameSpeed = 24,
    kNativeChromeZoomIn = 25,
    kNativeChromeZoomOut = 26,
    kNativeChromeRotateCW = 27,
    kNativeChromeViewUnderground = 28,
    kNativeChromeViewSeeThroughRides = 29,
    kNativeChromeViewSeeThroughScenery = 30,
    kNativeChromeViewGuests = 31,
    kNativeChromeViewStaff = 32,
    kNativeChromeViewPathIssues = 33,
    kNativeChromeViewHeightMarks = 34,
    kNativeChromeExtraXor = -1,
};

void* OpenRCT2TouchChromeAttach(void* parentView, void (*onAction)(int32_t, int32_t));
void OpenRCT2TouchChromeDetach(void* session);
void OpenRCT2TouchChromeSetParkOpen(void* session, bool open);
void OpenRCT2TouchChromeSetState(void* session, bool paused, uint8_t speed, uint32_t flags);
void OpenRCT2TouchChromeSetStatus(
    void* session, const char* cash, const char* guests, const char* rating, const char* date);
void OpenRCT2TouchChromeBringToFront(void* session);
void OpenRCT2TouchChromeHandleAction(int32_t code, int32_t extra);

#ifdef __cplusplus
}
#endif
