/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *
 * Dispatches Mac Liquid Glass toolbar actions using WIDX codes. For classic
 * dropdown widgets, `extra` is the dropdown index (FileMenuDdidx, etc.).
 *****************************************************************************/

#include "MacNativeChrome.h"

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

    #include "MacCocoaWindow.h"

    #include <SDL.h>
    #include <cstdio>
    #include <string>
    #include <string_view>

    #include <openrct2-ui/UiContext.h>
    #include <openrct2-ui/interface/InGameConsole.h>
    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>
    #include <openrct2/ui/UiContext.h>
    #include <openrct2/Cheats.h>
    #include <openrct2/Context.h>
    #include <openrct2/Date.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/Version.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/GameSetSpeedAction.h>
    #include <openrct2/actions/general/LoadOrQuitAction.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/audio/Audio.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/interface/Chat.h>
    #include <openrct2/interface/Screenshot.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/ui/WindowManager.h>
    #include <openrct2/management/NewsItem.h>
    #include <openrct2/world/Weather.h>

    #import <AppKit/AppKit.h>
    #import <Foundation/Foundation.h>

extern "C" {
void* OpenRCT2MacChromeAttach(void* contentView, void (*onAction)(int32_t, int32_t));
void OpenRCT2MacChromeDetach(void* session);
void OpenRCT2MacChromeBringToFront(void* session);
void OpenRCT2MacChromeSetIconPath(void* session, const char* path);
void OpenRCT2MacChromeSetCleanedSpritePath(void* session, const char* path);
void OpenRCT2MacChromeSetVersion(void* session, const char* version);
void OpenRCT2MacChromeSetStatus(
    void* session, const char* cash, const char* guests, const char* rating, const char* date, const char* temp,
    const char* weather);
void OpenRCT2MacChromeSetState(void* session, bool paused, bool muted, uint8_t speed);
void OpenRCT2MacChromeSetNewsToast(void* session, const char* message, bool showSubject, bool showLocate);
}

namespace
{
    constexpr int32_t kMacToastSubjectAction = 10001;
    constexpr int32_t kMacToastLocateAction = 10002;

    std::string StripFormatCodes(std::string_view in)
    {
        std::string out;
        out.reserve(in.size());
        for (size_t i = 0; i < in.size();)
        {
            if (in[i] == '{')
            {
                auto end = in.find('}', i);
                if (end != std::string_view::npos)
                {
                    i = end + 1;
                    continue;
                }
            }
            out.push_back(in[i]);
            ++i;
        }
        return out;
    }
}

namespace OpenRCT2::Ui
{
    namespace
    {
        void* gMacChromeSession = nullptr;

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

        // Match TopToolbar.cpp FileMenuDdidx / ViewMenu / etc.
        enum
        {
            DDIDX_NEW_GAME = 0,
            DDIDX_LOAD_GAME = 1,
            DDIDX_SAVE_GAME = 3,
            DDIDX_SAVE_GAME_AS = 4,
            DDIDX_SCREENSHOT = 6,
            DDIDX_GIANT_SCREENSHOT = 7,
            DDIDX_ABOUT = 9,
            DDIDX_FILE_BUG_ON_GITHUB = 10,
            DDIDX_OPTIONS = 12,
            DDIDX_QUIT_TO_MENU = 14,
            DDIDX_EXIT_OPENRCT2 = 15,
        };

        enum
        {
            DDIDX_UNDERGROUND_INSIDE = 0,
            DDIDX_TRANSPARENT_WATER = 1,
            DDIDX_HIDE_BASE = 2,
            DDIDX_HIDE_VERTICAL = 3,
            DDIDX_HIDE_RIDES = 5,
            DDIDX_HIDE_VEHICLES = 6,
            DDIDX_HIDE_VEGETATION = 7,
            DDIDX_HIDE_SCENERY = 8,
            DDIDX_HIDE_PATHS = 9,
            DDIDX_HIDE_SUPPORTS = 10,
            DDIDX_HIDE_GUESTS = 11,
            DDIDX_HIDE_STAFF = 12,
            DDIDX_LAND_HEIGHTS = 14,
            DDIDX_TRACK_HEIGHTS = 15,
            DDIDX_PATH_HEIGHTS = 16,
            DDIDX_VIEW_CLIPPING = 18,
            DDIDX_HIGHLIGHT_PATH_ISSUES = 19,
            DDIDX_TRANSPARENCY = 21,
        };

        std::string ResolveG2IconsPath()
        {
            if (const char* root = getenv("OPENRCT2_ROOT"))
                return std::string(root) + "/resources/g2/icons";
            if (const char* data = getenv("OPENRCT2_DATA"))
                return std::string(data) + "/../../resources/g2/icons";
            return {};
        }

        std::string ResolveCleanedSpritesPath()
        {
            if (const char* root = getenv("OPENRCT2_ROOT"))
                return std::string(root) + "/macos/platform/chrome/ToolbarSprites/cleaned";
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
                return;

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

            // Bottom-center Liquid Glass news toast (replaces suppressed bottom toolbar ticker).
            auto* newsItem = News::GetItem(0);
            if (newsItem != nullptr && !newsItem->isEmpty() && !newsItem->text.empty())
            {
                const auto plain = StripFormatCodes(newsItem->text);
                const bool showSubject = newsItem->typeHasSubject() && !newsItem->hasButton();
                bool showLocate = false;
                if (showSubject || newsItem->typeHasLocation())
                {
                    auto loc = News::GetSubjectLocation(newsItem->type, static_cast<int32_t>(newsItem->assoc));
                    showLocate = loc.has_value() && !newsItem->hasButton();
                }
                OpenRCT2MacChromeSetNewsToast(gMacChromeSession, plain.c_str(), showSubject, showLocate);
            }
            else
            {
                OpenRCT2MacChromeSetNewsToast(gMacChromeSession, "", false, false);
            }
        }

        void HandleFileMenu(int32_t selectedIndex)
        {
            auto& gameState = getGameState();
            switch (selectedIndex)
            {
                case DDIDX_NEW_GAME:
                {
                    auto loadOrQuitAction = GameActions::LoadOrQuitAction(
                        GameActions::LoadOrQuitModes::openSavePrompt, PromptMode::saveBeforeNewGame);
                    GameActions::Execute(&loadOrQuitAction, gameState);
                    break;
                }
                case DDIDX_LOAD_GAME:
                {
                    auto loadOrQuitAction = GameActions::LoadOrQuitAction(GameActions::LoadOrQuitModes::openSavePrompt);
                    GameActions::Execute(&loadOrQuitAction, gameState);
                    break;
                }
                case DDIDX_SAVE_GAME:
                    ToolCancel();
                    SaveGame();
                    break;
                case DDIDX_SAVE_GAME_AS:
                    ToolCancel();
                    SaveGameAs();
                    break;
                case DDIDX_SCREENSHOT:
                    gScreenshotCountdown = 10;
                    break;
                case DDIDX_GIANT_SCREENSHOT:
                    ScreenshotGiant();
                    break;
                case DDIDX_ABOUT:
                    // Native About panel shown from Swift; keep engine About as fallback.
                    ContextOpenWindow(WindowClass::about);
                    break;
                case DDIDX_FILE_BUG_ON_GITHUB:
                {
                    std::string url = "https://github.com/OpenRCT2/OpenRCT2/issues/new?"
                                      "assignees=&labels=bug&template=bug_report.yaml";
                    GetContext()->GetUiContext().OpenURL(url);
                    break;
                }
                case DDIDX_OPTIONS:
                    ContextOpenWindow(WindowClass::options);
                    break;
                case DDIDX_QUIT_TO_MENU:
                {
                    auto* windowMgr = GetWindowManager();
                    windowMgr->CloseByClass(WindowClass::manageTrackDesign);
                    windowMgr->CloseByClass(WindowClass::trackDeletePrompt);
                    auto loadOrQuitAction = GameActions::LoadOrQuitAction(
                        GameActions::LoadOrQuitModes::openSavePrompt, PromptMode::saveBeforeQuit);
                    GameActions::Execute(&loadOrQuitAction, gameState);
                    break;
                }
                case DDIDX_EXIT_OPENRCT2:
                    ContextQuit();
                    break;
                default:
                    break;
            }
        }

        void HandleViewMenu(int32_t dropdownIndex)
        {
            auto* w = WindowGetMain();
            if (w == nullptr || w->viewport == nullptr)
                return;

            switch (dropdownIndex)
            {
                case DDIDX_UNDERGROUND_INSIDE:
                    w->viewport->flags ^= VIEWPORT_FLAG_UNDERGROUND_INSIDE;
                    break;
                case DDIDX_TRANSPARENT_WATER:
                    Config::Get().general.transparentWater ^= 1;
                    Config::Save();
                    break;
                case DDIDX_HIDE_BASE:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_BASE;
                    break;
                case DDIDX_HIDE_VERTICAL:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_VERTICAL;
                    break;
                case DDIDX_HIDE_RIDES:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_RIDES;
                    break;
                case DDIDX_HIDE_VEHICLES:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_VEHICLES;
                    break;
                case DDIDX_HIDE_VEGETATION:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_VEGETATION;
                    break;
                case DDIDX_HIDE_SCENERY:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_SCENERY;
                    break;
                case DDIDX_HIDE_PATHS:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_PATHS;
                    break;
                case DDIDX_HIDE_SUPPORTS:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_SUPPORTS;
                    break;
                case DDIDX_HIDE_GUESTS:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_GUESTS;
                    break;
                case DDIDX_HIDE_STAFF:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIDE_STAFF;
                    break;
                case DDIDX_LAND_HEIGHTS:
                    w->viewport->flags ^= VIEWPORT_FLAG_LAND_HEIGHTS;
                    break;
                case DDIDX_TRACK_HEIGHTS:
                    w->viewport->flags ^= VIEWPORT_FLAG_TRACK_HEIGHTS;
                    break;
                case DDIDX_PATH_HEIGHTS:
                    w->viewport->flags ^= VIEWPORT_FLAG_PATH_HEIGHTS;
                    break;
                case DDIDX_VIEW_CLIPPING:
                {
                    auto* windowMgr = GetWindowManager();
                    if (windowMgr->FindByClass(WindowClass::viewClipping) == nullptr)
                        ContextOpenWindow(WindowClass::viewClipping);
                    else
                        w->viewport->flags ^= VIEWPORT_FLAG_CLIP_VIEW;
                    break;
                }
                case DDIDX_HIGHLIGHT_PATH_ISSUES:
                    w->viewport->flags ^= VIEWPORT_FLAG_HIGHLIGHT_PATH_ISSUES;
                    break;
                case DDIDX_TRANSPARENCY:
                    ContextOpenWindow(WindowClass::transparency);
                    break;
                default:
                    return;
            }
            w->invalidate();
        }

        void HandleCheatsMenu(int32_t dropdownIndex)
        {
            using namespace OpenRCT2::Ui::Windows;
            switch (dropdownIndex)
            {
                case 0:
                    ContextOpenWindow(WindowClass::cheats);
                    break;
                case 1:
                    ContextOpenWindow(WindowClass::tileInspector);
                    break;
                case 2:
                {
                    auto* windowMgr = GetWindowManager();
                    windowMgr->CloseAll();
                    ContextOpenWindow(WindowClass::editorObjectSelection);
                    break;
                }
                case 3:
                    ContextOpenWindow(WindowClass::editorInventionList);
                    break;
                case 4:
                    ContextOpenWindow(WindowClass::editorScenarioOptions);
                    break;
                case 6:
                    CheatsSet(CheatType::sandboxMode, !getGameState().cheats.sandboxMode);
                    break;
                case 7:
                    CheatsSet(CheatType::disableClearanceChecks, !getGameState().cheats.disableClearanceChecks);
                    break;
                case 8:
                    CheatsSet(CheatType::disableSupportLimits, !getGameState().cheats.disableSupportLimits);
                    break;
                default:
                    break;
            }
        }

        void MacChromeOnAction(int32_t code, int32_t extra)
        {
            using namespace OpenRCT2::Ui::Windows;

            LOG_INFO("Mac Liquid Glass chrome WIDX=%d extra=%d", code, extra);

            if (code == kMacToastSubjectAction)
            {
                if (auto* newsItem = News::GetItem(0); newsItem != nullptr && !newsItem->isEmpty())
                    News::OpenSubject(newsItem->type, static_cast<int32_t>(newsItem->assoc));
                return;
            }
            if (code == kMacToastLocateAction)
            {
                if (auto* newsItem = News::GetItem(0); newsItem != nullptr && !newsItem->isEmpty())
                {
                    auto subjectLoc = News::GetSubjectLocation(newsItem->type, static_cast<int32_t>(newsItem->assoc));
                    if (subjectLoc.has_value())
                    {
                        if (auto* mainWindow = WindowGetMain(); mainWindow != nullptr)
                            WindowScrollToLocation(*mainWindow, subjectLoc.value());
                    }
                }
                return;
            }

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
                {
                    // extra = speed menu index 0..3,5 → GameSetSpeedAction
                    if (extra >= 0 && extra <= 5)
                    {
                        auto newSpeed = extra + 1;
                        if (newSpeed >= 5)
                            newSpeed = 8;
                        auto setSpeedAction = GameActions::GameSetSpeedAction(static_cast<uint8_t>(newSpeed));
                        GameActions::Execute(&setSpeedAction, getGameState());
                    }
                    break;
                }
                case TopToolbarWIDX::FileMenu:
                    HandleFileMenu(extra);
                    break;
                case TopToolbarWIDX::Mute:
                    Audio::ToggleAllSounds();
                    break;
                case TopToolbarWIDX::Network:
                    if (extra == 1)
                        Network::Reconnect();
                    else
                        ContextOpenWindow(WindowClass::multiplayer);
                    break;
                case TopToolbarWIDX::Chat:
                    if (ChatAvailable())
                        ChatToggle();
                    break;
                case TopToolbarWIDX::Cheats:
                    HandleCheatsMenu(extra);
                    break;
                case TopToolbarWIDX::Debug:
                    if (extra == 0)
                    {
                        auto& console = GetInGameConsole();
                        console.Open();
                    }
                    else if (extra == 1)
                    {
                        auto* windowMgr = GetWindowManager();
                        if (windowMgr->FindByClass(WindowClass::debugPaint) == nullptr)
                            ContextOpenWindow(WindowClass::debugPaint);
                        else
                            windowMgr->CloseByClass(WindowClass::debugPaint);
                    }
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
                    HandleViewMenu(extra);
                    break;
                case TopToolbarWIDX::Map:
                    if (extra == 1)
                        ContextOpenWindow(WindowClass::viewport);
                    else if (extra == 2)
                        ContextOpenWindow(WindowClass::mapgen);
                    else
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

    static void MacApplyImmersiveTitlebar(NSWindow* nsWindow)
    {
        // Park fills the full window under traffic lights (CJ).
        nsWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
        nsWindow.titlebarAppearsTransparent = YES;
        nsWindow.titleVisibility = NSWindowTitleHidden;
        // Keep standard traffic lights; do not hide close/miniaturize/zoom.
    }

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

            MacApplyImmersiveTitlebar(nsWindow);

            NSView* contentView = nsWindow.contentView;
            if (contentView == nil)
            {
                LOG_WARNING("MacNativeChromeAttach: NSWindow has no contentView");
                return;
            }

            if (!contentView.wantsLayer)
                contentView.wantsLayer = YES;

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
                OpenRCT2MacChromeSetIconPath(gMacChromeSession, iconPath.c_str());

            const auto cleanedPath = ResolveCleanedSpritesPath();
            if (!cleanedPath.empty())
                OpenRCT2MacChromeSetCleanedSpritePath(gMacChromeSession, cleanedPath.c_str());

            OpenRCT2MacChromeSetVersion(gMacChromeSession, gVersionInfoFull);

            MacChromeRefreshStatus();
            LOG_INFO("Mac Liquid Glass chrome attached (Option 1 + NSMenu)");
        }
    }

    void MacNativeChromeDetach()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
                return;
            OpenRCT2MacChromeDetach(gMacChromeSession);
            gMacChromeSession = nullptr;
        }
    }

    void MacNativeChromeTick()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
                return;
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
