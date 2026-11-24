/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Dispatches Mac Liquid Glass toolbar actions using the same WIDX codes and
 * engine calls as TopToolbar::onMouseUp / primary paths for onMouseDown menus.
 *****************************************************************************/

#include "MacNativeChrome.h"

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

    #include "MacCocoaWindow.h"

    #include <SDL.h>
    #include <cstdio>
    #include <string>

    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>
    #include <openrct2/Context.h>
    #include <openrct2/Date.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/audio/Audio.h>
    #include <openrct2/interface/Chat.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/world/Weather.h>

    #import <AppKit/AppKit.h>
    #import <Foundation/Foundation.h>

extern "C" {
void* OpenRCT2MacChromeAttach(void* contentView, void (*onAction)(int32_t, int32_t));
void OpenRCT2MacChromeDetach(void* session);
void OpenRCT2MacChromeBringToFront(void* session);
void OpenRCT2MacChromeSetIconPath(void* session, const char* path);
void OpenRCT2MacChromeSetStatus(
    void* session, const char* cash, const char* guests, const char* rating, const char* date, const char* temp,
    const char* weather);
void OpenRCT2MacChromeSetState(void* session, bool paused, bool muted, uint8_t speed);
}

namespace OpenRCT2::Ui
{
    namespace
    {
        void* gMacChromeSession = nullptr;

        // Must match WindowTopToolbarWidgetIdx in TopToolbar.cpp
        enum class TopToolbarWIDX : int32_t
        {
            Pause = 0,
            FileMenu,
            Mute,
            ZoomOut,
            ZoomIn,
            RotateAntiClockwise,
            RotateClockwise,
            ViewMenu,
            Map,
            Land,
            Water,
            Scenery,
            Path,
            ConstructRide,
            Rides,
            Park,
            Staff,
            Guests,
            ClearScenery,
            FastForward,
            Cheats,
            Debug,
            Finances,
            Research,
            News,
            Network,
            Chat,
        };

        std::string ResolveG2IconsPath()
        {
            if (const char* root = getenv("OPENRCT2_ROOT"))
            {
                return std::string(root) + "/resources/g2/icons";
            }
            if (const char* data = getenv("OPENRCT2_DATA"))
            {
                // assets/engine → ../../resources/g2/icons when using repo layout
                return std::string(data) + "/../../resources/g2/icons";
            }
            return {};
        }

        const char* WeatherLabel(Weather::Type type)
        {
            switch (type)
            {
                case Weather::Type::sunny:
                    return "Sunny";
                case Weather::Type::partiallyCloudy:
                    return "Partly cloudy";
                case Weather::Type::cloudy:
                    return "Cloudy";
                case Weather::Type::rain:
                    return "Rain";
                case Weather::Type::heavyRain:
                    return "Heavy rain";
                case Weather::Type::thunder:
                    return "Thunder";
                case Weather::Type::snow:
                    return "Snow";
                case Weather::Type::heavySnow:
                    return "Heavy snow";
                case Weather::Type::blizzard:
                    return "Blizzard";
                default:
                    return "Clear";
            }
        }

        void MacChromeRefreshStatus()
        {
            if (gMacChromeSession == nullptr)
            {
                return;
            }

            auto& gameState = getGameState();
            char cashBuf[64];
            char guestsBuf[64];
            char ratingBuf[64];
            char dateBuf[64];
            char tempBuf[32];
            char weatherBuf[64];

            const auto cash = gameState.park.cash;
            if (cash < 0)
            {
                std::snprintf(
                    cashBuf, sizeof(cashBuf), "-$%lld.%lld", static_cast<long long>((-cash) / 10),
                    static_cast<long long>((-cash) % 10));
            }
            else
            {
                std::snprintf(
                    cashBuf, sizeof(cashBuf), "$%lld.%lld", static_cast<long long>(cash / 10),
                    static_cast<long long>(cash % 10));
            }

            std::snprintf(
                guestsBuf, sizeof(guestsBuf), "%u guests", static_cast<unsigned>(gameState.park.numGuestsInPark));
            std::snprintf(ratingBuf, sizeof(ratingBuf), "Rating %u", static_cast<unsigned>(gameState.park.rating));

            const auto& date = GetDate();
            static constexpr const char* kMonths[] = { "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct" };
            const int month = date.GetMonth();
            const char* monthName = (month >= 0 && month < 8) ? kMonths[month] : "?";
            std::snprintf(dateBuf, sizeof(dateBuf), "%s %d, Y%d", monthName, date.GetDay() + 1, date.GetYear() + 1);

            std::snprintf(tempBuf, sizeof(tempBuf), "%d°C", static_cast<int>(gameState.weatherCurrent.temperature));
            std::snprintf(weatherBuf, sizeof(weatherBuf), "%s", WeatherLabel(gameState.weatherCurrent.weatherType));

            OpenRCT2MacChromeSetStatus(gMacChromeSession, cashBuf, guestsBuf, ratingBuf, dateBuf, tempBuf, weatherBuf);
            OpenRCT2MacChromeSetState(
                gMacChromeSession, (gGamePaused & GAME_PAUSED_NORMAL) != 0, Audio::gGameSoundsOff, gGameSpeed);
        }

        void MacChromeOnAction(int32_t code, int32_t extra)
        {
            using namespace OpenRCT2::Ui::Windows;
            (void)extra;

            LOG_INFO("Mac Liquid Glass chrome WIDX=%d extra=%d", code, extra);

            auto* mainWindow = WindowGetMain();
            auto widx = static_cast<TopToolbarWIDX>(code);

            switch (widx)
            {
                case TopToolbarWIDX::Pause:
                    if (Network::GetMode() != Network::Mode::client)
                    {
                        auto pauseToggleAction = GameActions::PauseToggleAction();
                        GameActions::Execute(&pauseToggleAction, getGameState());
                    }
                    break;
                case TopToolbarWIDX::FastForward:
                    // Classic: dropdown. Primary path: increase speed.
                    GameIncreaseGameSpeed();
                    break;
                case TopToolbarWIDX::FileMenu:
                    // Classic: file dropdown. Primary path: options window.
                    ContextOpenWindow(WindowClass::options);
                    break;
                case TopToolbarWIDX::Mute:
                    Audio::ToggleAllSounds();
                    break;
                case TopToolbarWIDX::Network:
                    ContextOpenWindow(WindowClass::multiplayer);
                    break;
                case TopToolbarWIDX::Chat:
                    if (ChatAvailable())
                    {
                        ChatToggle();
                    }
                    break;
                case TopToolbarWIDX::Cheats:
                    ContextOpenWindow(WindowClass::cheats);
                    break;
                case TopToolbarWIDX::Debug:
                    ContextOpenWindow(WindowClass::tileInspector);
                    break;
                case TopToolbarWIDX::ZoomOut:
                    if (mainWindow != nullptr)
                        WindowZoomOut(*mainWindow, false);
                    break;
                case TopToolbarWIDX::ZoomIn:
                    if (mainWindow != nullptr)
                        WindowZoomIn(*mainWindow, false);
                    break;
                case TopToolbarWIDX::RotateAntiClockwise:
                    ViewportRotateAll(-1);
                    break;
                case TopToolbarWIDX::RotateClockwise:
                    ViewportRotateAll(1);
                    break;
                case TopToolbarWIDX::ViewMenu:
                    ContextOpenWindow(WindowClass::transparency);
                    break;
                case TopToolbarWIDX::Map:
                    ContextOpenWindow(WindowClass::map);
                    break;
                case TopToolbarWIDX::ClearScenery:
                    ToggleClearSceneryWindow();
                    break;
                case TopToolbarWIDX::Land:
                    ToggleLandWindow();
                    break;
                case TopToolbarWIDX::Water:
                    ToggleWaterWindow();
                    break;
                case TopToolbarWIDX::Scenery:
                    ToggleSceneryWindow();
                    break;
                case TopToolbarWIDX::Path:
                    ToggleFootpathWindow();
                    break;
                case TopToolbarWIDX::ConstructRide:
                    ContextOpenWindow(WindowClass::constructRide);
                    break;
                case TopToolbarWIDX::Finances:
                    ContextOpenWindow(WindowClass::finances);
                    break;
                case TopToolbarWIDX::Research:
                    ContextOpenWindow(WindowClass::research);
                    break;
                case TopToolbarWIDX::Rides:
                    ContextOpenWindow(WindowClass::rideList);
                    break;
                case TopToolbarWIDX::Park:
                    ContextOpenWindow(WindowClass::parkInformation);
                    break;
                case TopToolbarWIDX::Staff:
                    ContextOpenWindow(WindowClass::staffList);
                    break;
                case TopToolbarWIDX::Guests:
                    ContextOpenWindow(WindowClass::guestList);
                    break;
                case TopToolbarWIDX::News:
                    ContextOpenWindow(WindowClass::recentNews);
                    break;
            }
        }
    } // namespace

    void MacNativeChromeAttach(SDL_Window* window)
    {
        @autoreleasepool
        {
            MacNativeChromeDetach();

            NSWindow* nsWindow = MacCocoaWindowFromSdl(window);
            if (nsWindow == nil)
            {
                LOG_WARNING("MacNativeChromeAttach: could not resolve NSWindow from SDL");
                return;
            }

            NSView* contentView = nsWindow.contentView;
            if (contentView == nil)
            {
                LOG_WARNING("MacNativeChromeAttach: NSWindow has no contentView");
                return;
            }

            if (!contentView.wantsLayer)
            {
                contentView.wantsLayer = YES;
            }

            void* contentViewPtr = static_cast<void*>(contentView);
            const char* glassEnv = getenv("OPENRCT2_MAC_GLASS");
            if (glassEnv != nullptr && (glassEnv[0] == '0') && (glassEnv[1] == '\0'))
            {
                LOG_INFO("Mac Liquid Glass chrome skipped (OPENRCT2_MAC_GLASS=0)");
                return;
            }

            gMacChromeSession = OpenRCT2MacChromeAttach(contentViewPtr, &MacChromeOnAction);
            if (gMacChromeSession == nullptr)
            {
                LOG_WARNING("MacNativeChromeAttach: Swift chrome attach failed");
                return;
            }

            const auto iconPath = ResolveG2IconsPath();
            if (!iconPath.empty())
            {
                OpenRCT2MacChromeSetIconPath(gMacChromeSession, iconPath.c_str());
            }

            MacChromeRefreshStatus();
            LOG_INFO("Mac Liquid Glass chrome attached (Option 1 / WIDX 1:1)");
        }
    }

    void MacNativeChromeDetach()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
            {
                return;
            }
            OpenRCT2MacChromeDetach(gMacChromeSession);
            gMacChromeSession = nullptr;
        }
    }

    void MacNativeChromeTick()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
            {
                return;
            }
            OpenRCT2MacChromeBringToFront(gMacChromeSession);
            MacChromeRefreshStatus();
        }
    }

    bool MacNativeChromeHandleEvent([[maybe_unused]] const SDL_Event& event)
    {
        return false;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_OSX
