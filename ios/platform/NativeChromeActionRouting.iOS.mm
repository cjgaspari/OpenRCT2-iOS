/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChromeActionRouting.iOS.h"
#include "NativeChromeParkState.iOS.h"
#include "chrome/ParkChromeActions.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <algorithm>
    #include <openrct2/Context.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/GameSetSpeedAction.h>
    #include <openrct2/actions/general/LoadOrQuitAction.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/interface/WindowTypes.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/ui/WindowManager.h>
    #include <openrct2/windows/Intent.h>
    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>

namespace OpenRCT2::Ui
{
    namespace
    {
        constexpr uint32_t kHeightMarkFlags = OpenRCT2::VIEWPORT_FLAG_LAND_HEIGHTS | OpenRCT2::VIEWPORT_FLAG_TRACK_HEIGHTS
            | OpenRCT2::VIEWPORT_FLAG_PATH_HEIGHTS;

        void ApplyViewportFlag(uint32_t flag, int32_t extra, bool switchOnClearsFlag)
        {
            auto* w = WindowGetMain();
            if (w == nullptr || w->viewport == nullptr)
            {
                return;
            }

            if (extra < 0)
            {
                w->viewport->flags ^= flag;
            }
            else if (switchOnClearsFlag)
            {
                if (extra != 0)
                {
                    w->viewport->flags &= ~flag;
                }
                else
                {
                    w->viewport->flags |= flag;
                }
            }
            else if (extra != 0)
            {
                w->viewport->flags |= flag;
            }
            else
            {
                w->viewport->flags &= ~flag;
            }
            w->invalidate();
        }

        void ApplyHeightMarks(int32_t extra)
        {
            auto* w = WindowGetMain();
            if (w == nullptr || w->viewport == nullptr)
            {
                return;
            }

            if (extra < 0)
            {
                if ((w->viewport->flags & kHeightMarkFlags) != 0)
                {
                    w->viewport->flags &= ~kHeightMarkFlags;
                }
                else
                {
                    w->viewport->flags |= kHeightMarkFlags;
                }
            }
            else if (extra != 0)
            {
                w->viewport->flags |= kHeightMarkFlags;
            }
            else
            {
                w->viewport->flags &= ~kHeightMarkFlags;
            }
            w->invalidate();
        }

        void SetGameSpeed(uint8_t speed)
        {
            if (speed < 1 || speed > 4)
            {
                speed = 1;
            }
            auto setSpeedAction = GameActions::GameSetSpeedAction(speed);
            GameActions::Execute(&setSpeedAction, getGameState());
        }

        void CycleGameSpeed()
        {
            uint8_t newSpeed = gGameSpeed + 1;
            if (newSpeed < 1 || newSpeed > 4)
            {
                newSpeed = 1;
            }
            SetGameSpeed(newSpeed);
        }

        void CentreOpenedWindow(WindowBase* w)
        {
            if (w == nullptr)
            {
                return;
            }
            if (w->classification == WindowClass::mainWindow)
            {
                return;
            }
            if (w->flags.hasAny(WindowFlag::stickToBack, WindowFlag::stickToFront))
            {
                return;
            }

            const int32_t screenWidth = ContextGetWidth();
            const int32_t screenHeight = ContextGetHeight();
            const int32_t x = std::clamp((screenWidth - w->width) / 2, 0, std::max(0, screenWidth - w->width));
            const int32_t y = std::clamp((screenHeight - w->height) / 2, 0, std::max(0, screenHeight - w->height));
            Windows::WindowSetPosition(*w, { x, y });
        }

        void CentreWindowClass(WindowClass cls)
        {
            auto* windowMgr = GetWindowManager();
            if (windowMgr == nullptr)
            {
                return;
            }
            CentreOpenedWindow(windowMgr->FindByClass(cls));
        }
    } // namespace

    const char* NativeChromeActionLogName(int32_t code)
    {
        switch (code)
        {
            case kNativeChromeBuildNewRide:
                return "build-ride";
            case kNativeChromeTrees:
                return "trees";
            case kNativeChromePaths:
                return "paths";
            case kNativeChromeLand:
                return "land";
            case kNativeChromeWater:
                return "water";
            case kNativeChromeClearScenery:
                return "clear-scenery";
            case kNativeChromeRideList:
                return "ride-list";
            case kNativeChromeParkInformation:
                return "park-information";
            case kNativeChromeStaffList:
                return "staff-list";
            case kNativeChromeGuestList:
                return "guest-list";
            case kNativeChromeFinances:
                return "finances";
            case kNativeChromeResearch:
                return "research";
            case kNativeChromeRecentNews:
                return "recent-news";
            case kNativeChromeMap:
                return "map";
            case kNativeChromeExtraViewport:
                return "extra-viewport";
            case kNativeChromeViewClipping:
                return "view-clipping";
            case kNativeChromeTransparency:
                return "transparency";
            case kNativeChromeLoadSave:
                return "loadsave";
            case kNativeChromeOptions:
                return "options";
            case kNativeChromeAbout:
                return "about";
            case kNativeChromeCheats:
                return "cheats";
            case kNativeChromeTileInspector:
                return "tile-inspector";
            case kNativeChromePause:
                return "pause";
            case kNativeChromeGameSpeed:
                return "game-speed";
            case kNativeChromeZoomIn:
                return "zoom-in";
            case kNativeChromeZoomOut:
                return "zoom-out";
            case kNativeChromeRotateCW:
                return "rotate";
            case kNativeChromeViewHeightMarks:
                return "view-height-marks";
            case kNativeChromeQuitToMenu:
                return "quit-to-menu";
            case kNativeChromeScenarioStart:
                return "scenario-start";
            case kNativeChromeScenarioCancel:
                return "scenario-cancel";
            case kNativeChromeScenarioSource:
                return "scenario-source";
            case kNativeChromeScenarioPreview:
                return "scenario-preview";
            default:
                return "view-toggle";
        }
    }

    bool NativeChromeRouteParkAction(int32_t code, int32_t extra)
    {
        if (!NativeChromeParkIsOpen())
        {
            return false;
        }

        WindowBase* mainWindow = nullptr;
        switch (code)
        {
            case kNativeChromeBuildNewRide:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::constructRide));
                break;
            case kNativeChromeTrees:
                Windows::ToggleSceneryWindow();
                CentreWindowClass(WindowClass::scenery);
                break;
            case kNativeChromePaths:
                Windows::ToggleFootpathWindow();
                CentreWindowClass(WindowClass::footpath);
                break;
            case kNativeChromeLand:
                Windows::ToggleLandWindow();
                CentreWindowClass(WindowClass::land);
                break;
            case kNativeChromeWater:
                Windows::ToggleWaterWindow();
                CentreWindowClass(WindowClass::water);
                break;
            case kNativeChromeClearScenery:
                Windows::ToggleClearSceneryWindow();
                CentreWindowClass(WindowClass::clearScenery);
                break;
            case kNativeChromeRideList:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::rideList));
                break;
            case kNativeChromeParkInformation:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::parkInformation));
                break;
            case kNativeChromeStaffList:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::staffList));
                break;
            case kNativeChromeGuestList:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::guestList));
                break;
            case kNativeChromeFinances:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::finances));
                break;
            case kNativeChromeResearch:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::research));
                break;
            case kNativeChromeRecentNews:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::recentNews));
                break;
            case kNativeChromeMap:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::map));
                break;
            case kNativeChromeExtraViewport:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::viewport));
                break;
            case kNativeChromeViewClipping:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::viewClipping));
                break;
            case kNativeChromeTransparency:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::transparency));
                break;
            case kNativeChromeLoadSave:
                SaveGameAs();
                CentreWindowClass(WindowClass::loadsave);
                break;
            case kNativeChromeLoadGame:
            {
                auto intent = Intent(WindowClass::loadsave);
                intent.PutEnumExtra<LoadSaveAction>(INTENT_EXTRA_LOADSAVE_ACTION, LoadSaveAction::load);
                intent.PutEnumExtra<LoadSaveType>(INTENT_EXTRA_LOADSAVE_TYPE, LoadSaveType::park);
                ContextOpenIntent(&intent);
                break;
            }
            case kNativeChromeOptions:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::options));
                break;
            case kNativeChromeAbout:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::about));
                break;
            case kNativeChromeCheats:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::cheats));
                break;
            case kNativeChromeTileInspector:
                CentreOpenedWindow(OpenRCT2::ContextOpenWindow(WindowClass::tileInspector));
                break;
            case kNativeChromePause:
                if (Network::GetMode() != Network::Mode::client)
                {
                    auto pauseToggleAction = GameActions::PauseToggleAction();
                    GameActions::Execute(&pauseToggleAction, getGameState());
                }
                break;
            case kNativeChromeGameSpeed:
                if (extra >= 1 && extra <= 4)
                {
                    SetGameSpeed(static_cast<uint8_t>(extra));
                }
                else
                {
                    CycleGameSpeed();
                }
                break;
            case kNativeChromeZoomIn:
                mainWindow = WindowGetMain();
                if (mainWindow != nullptr)
                {
                    Windows::WindowZoomIn(*mainWindow, false);
                }
                break;
            case kNativeChromeZoomOut:
                mainWindow = WindowGetMain();
                if (mainWindow != nullptr)
                {
                    Windows::WindowZoomOut(*mainWindow, false);
                }
                break;
            case kNativeChromeRotateCW:
                ViewportRotateAll(1);
                break;
            case kNativeChromeViewUnderground:
                ApplyViewportFlag(VIEWPORT_FLAG_UNDERGROUND_INSIDE, extra, false);
                break;
            case kNativeChromeViewSeeThroughRides:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_RIDES, extra, false);
                break;
            case kNativeChromeViewSeeThroughScenery:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_SCENERY, extra, false);
                break;
            case kNativeChromeViewGuests:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_GUESTS, extra, true);
                break;
            case kNativeChromeViewStaff:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_STAFF, extra, true);
                break;
            case kNativeChromeViewPathIssues:
                ApplyViewportFlag(VIEWPORT_FLAG_HIGHLIGHT_PATH_ISSUES, extra, false);
                break;
            case kNativeChromeViewHeightMarks:
                ApplyHeightMarks(extra);
                break;
            case kNativeChromeQuitToMenu:
            {
                auto* windowMgr = GetWindowManager();
                if (windowMgr != nullptr)
                {
                    windowMgr->CloseByClass(WindowClass::manageTrackDesign);
                    windowMgr->CloseByClass(WindowClass::trackDeletePrompt);
                }
                auto loadOrQuitAction = GameActions::LoadOrQuitAction(
                    GameActions::LoadOrQuitModes::openSavePrompt, PromptMode::saveBeforeQuit);
                GameActions::Execute(&loadOrQuitAction, getGameState());
                CentreWindowClass(WindowClass::savePrompt);
                break;
            }
            default:
                break;
        }
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
