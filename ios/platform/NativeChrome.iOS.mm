/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "chrome/ParkChromeActions.h"

    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>

    #include <SDL.h>
    #include <SDL_syswm.h>
    #include <UIKit/UIKit.h>
    #include <cstdint>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/GameSetSpeedAction.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/Date.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/localisation/Currency.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/scenes/SceneManager.h>
    #include <openrct2/ui/WindowManager.h>
    #include <os/log.h>

@class OpenRCT2TouchNativeChrome;

namespace
{
    constexpr uint32_t kHeightMarkFlags = OpenRCT2::VIEWPORT_FLAG_LAND_HEIGHTS | OpenRCT2::VIEWPORT_FLAG_TRACK_HEIGHTS
        | OpenRCT2::VIEWPORT_FLAG_PATH_HEIGHTS;

    Uint32 gNativeChromeEventType = 0;

    Uint32 EnsureNativeChromeEventType()
    {
        if (gNativeChromeEventType == 0)
        {
            gNativeChromeEventType = SDL_RegisterEvents(1);
        }
        return gNativeChromeEventType;
    }

    void QueueChromeAction(int32_t code, const char* name, int32_t extra)
    {
        const Uint32 eventType = EnsureNativeChromeEventType();
        if (eventType == 0 || eventType == static_cast<Uint32>(-1))
        {
            LOG_ERROR("[OpenRCT2Touch] native chrome: SDL user event registration failed");
            return;
        }

        SDL_Event event{};
        event.type = eventType;
        event.user.code = code;
        event.user.data1 = reinterpret_cast<void*>(static_cast<intptr_t>(extra));
        if (SDL_PushEvent(&event) != 1)
        {
            LOG_ERROR("[OpenRCT2Touch] native chrome: failed to queue %s action", name);
            return;
        }

        NSLog(@"[OpenRCT2Touch] native chrome: queued %s action", name);
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: queued %{public}s action", name);
    }

    NSString* FormatParkCash(money64 cash)
    {
        char amount[OpenRCT2::kMoneyStringMaxlength];
        OpenRCT2::MoneyToString(cash, amount, sizeof(amount), false);
        const auto& currency = OpenRCT2::CurrencyDescriptors[EnumValue(
            OpenRCT2::Config::Get().general.currencyFormat)];
        if (currency.affix_unicode == OpenRCT2::CurrencyAffix::prefix)
        {
            return [NSString stringWithFormat:@"%s%s", currency.symbol_unicode, amount];
        }
        return [NSString stringWithFormat:@"%s%s", amount, currency.symbol_unicode];
    }

    NSString* FormatParkDate(const OpenRCT2::Date& date)
    {
        static NSString* const kMonthNames[] = {
            @"Mar",
            @"Apr",
            @"May",
            @"Jun",
            @"Jul",
            @"Aug",
            @"Sep",
            @"Oct",
        };
        int32_t month = date.GetMonth();
        if (month < 0)
        {
            month = 0;
        }
        else if (month >= MONTH_COUNT)
        {
            month = MONTH_COUNT - 1;
        }
        return [NSString stringWithFormat:@"%@ %d", kMonthNames[month], date.GetDay() + 1];
    }

    const char* ActionLogName(int32_t code)
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
            default:
                return "view-toggle";
        }
    }
} // namespace

extern "C" void OpenRCT2TouchChromeHandleAction(int32_t code, int32_t extra)
{
    QueueChromeAction(code, ActionLogName(code), extra);
}

@interface OpenRCT2TouchNativeChrome : NSObject
{
    void* _session;
    UIView* _hostView;
    BOOL _parkOpen;
}

- (void)attachToView:(UIView*)parent;
- (void)detach;
- (void)setParkOpen:(BOOL)open;
- (void)updateParkChromeStatePaused:(BOOL)paused speed:(uint8_t)speed flags:(uint32_t)flags;
- (void)updateStatusCash:(NSString*)cash guests:(NSString*)guests rating:(NSString*)rating date:(NSString*)date;

@end

@implementation OpenRCT2TouchNativeChrome

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self detach];
    [super dealloc];
}

- (void)attachToView:(UIView*)parent
{
    if (parent == nil)
    {
        return;
    }

    if (_hostView == parent && _session != nullptr)
    {
        OpenRCT2TouchChromeBringToFront(_session);
        return;
    }

    [self detach];
    _hostView = parent;
    _session = OpenRCT2TouchChromeAttach(static_cast<void*>(parent), OpenRCT2TouchChromeHandleAction);
    if (_session == nullptr)
    {
        NSLog(@"[OpenRCT2Touch] native chrome: SwiftUI overlay attach failed");
        os_log_error(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: SwiftUI overlay attach failed");
        _hostView = nil;
        return;
    }

    NSLog(@"[OpenRCT2Touch] native chrome: attached SwiftUI park overlay");
    os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: attached SwiftUI park overlay");
}

- (void)detach
{
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeDetach(_session);
        _session = nullptr;
    }
    _hostView = nil;
    _parkOpen = NO;
}

- (void)setParkOpen:(BOOL)open
{
    _parkOpen = open;
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeSetParkOpen(_session, open);
    }
}

- (void)updateParkChromeStatePaused:(BOOL)paused speed:(uint8_t)speed flags:(uint32_t)flags
{
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeSetState(_session, paused, speed, flags);
    }
}

- (void)updateStatusCash:(NSString*)cash guests:(NSString*)guests rating:(NSString*)rating date:(NSString*)date
{
    if (_session == nullptr)
    {
        return;
    }
    OpenRCT2TouchChromeSetStatus(
        _session, cash.UTF8String, guests.UTF8String, rating.UTF8String, date.UTF8String);
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    (void)notification;
    if (_session == nullptr || _hostView == nil || _hostView.superview == nil)
    {
        OpenRCT2::Ui::NativeChromeAttach(nullptr);
    }
    else
    {
        OpenRCT2TouchChromeBringToFront(_session);
    }
}

@end

namespace OpenRCT2::Ui
{
    namespace
    {
        OpenRCT2TouchNativeChrome* gNativeChrome = nil;
        int gChromeLastParkOpen = -1;
        int gChromeLastPaused = -1;
        int gChromeLastSpeed = -1;
        uint32_t gChromeLastFlags = 0xFFFFFFFFu;
        money64 gChromeLastCash = kMoney64Undefined;
        uint32_t gChromeLastGuests = 0xFFFFFFFFu;
        uint16_t gChromeLastRating = 0xFFFFu;
        int32_t gChromeLastMonth = -1;
        int32_t gChromeLastDay = -1;

        UIWindow* WindowFromSdl(SDL_Window* window)
        {
            if (window != nullptr)
            {
                SDL_SysWMinfo windowInfo = {};
                SDL_VERSION(&windowInfo.version);
                if (SDL_GetWindowWMInfo(window, &windowInfo) == SDL_TRUE && windowInfo.subsystem == SDL_SYSWM_UIKIT)
                {
                    UIWindow* uikitWindow = windowInfo.info.uikit.window;
                    if (uikitWindow != nil && uikitWindow.rootViewController != nil)
                    {
                        return uikitWindow;
                    }
                }
            }

            UIWindow* fallback = nil;
            for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
            {
                if (![scene isKindOfClass:UIWindowScene.class])
                {
                    continue;
                }

                for (UIWindow* candidate in static_cast<UIWindowScene*>(scene).windows)
                {
                    if (candidate.hidden || candidate.rootViewController == nil)
                    {
                        continue;
                    }

                    fallback = candidate;
                    if (candidate.isKeyWindow)
                    {
                        return candidate;
                    }
                }
            }
            return fallback;
        }

        void AttachOnMainThread(SDL_Window* window)
        {
            if (gNativeChrome == nil)
            {
                gNativeChrome = [OpenRCT2TouchNativeChrome new];
            }

            UIWindow* host = WindowFromSdl(window);
            UIView* parent = host.rootViewController.view;
            if (host == nil || parent == nil)
            {
                NSLog(@"[OpenRCT2Touch] native chrome: no UIKit window yet");
                os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: no UIKit window yet");
                return;
            }

            [gNativeChrome attachToView:parent];
            gChromeLastParkOpen = -1;
        }

        bool ParkIsOpen()
        {
            auto* context = OpenRCT2::GetContext();
            if (context == nullptr)
            {
                return false;
            }

            auto* sceneMgr = context->GetSceneManager();
            if (sceneMgr == nullptr || sceneMgr->getActiveScene() == nullptr
                || sceneMgr->getActiveScene() != sceneMgr->getGameScene())
            {
                return false;
            }

            if (gLegacyScene != LegacyScene::playing || isInTrackDesignerOrManager())
            {
                return false;
            }

            auto* windowMgr = GetWindowManager();
            if (windowMgr == nullptr)
            {
                return false;
            }
            if (windowMgr->FindByClass(WindowClass::progressWindow) != nullptr
                || windowMgr->FindByClass(WindowClass::titleMenu) != nullptr
                || windowMgr->FindByClass(WindowClass::titleLogo) != nullptr
                || windowMgr->FindByClass(WindowClass::titleExit) != nullptr
                || windowMgr->FindByClass(WindowClass::titleOptions) != nullptr
                || windowMgr->FindByClass(WindowClass::scenarioSelect) != nullptr)
            {
                return false;
            }

            return true;
        }

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

        void CycleGameSpeed()
        {
            uint8_t newSpeed = gGameSpeed + 1;
            if (newSpeed < 1 || newSpeed > 4)
            {
                newSpeed = 1;
            }
            auto setSpeedAction = GameActions::GameSetSpeedAction(newSpeed);
            GameActions::Execute(&setSpeedAction, getGameState());
        }
    } // namespace

    void NativeChromeAttach(SDL_Window* window)
    {
        static SDL_Window* sWindow = nullptr;
        if (window != nullptr)
        {
            sWindow = window;
        }

        EnsureNativeChromeEventType();

        SDL_Window* target = window != nullptr ? window : sWindow;
        auto attach = ^{
            AttachOnMainThread(target);
        };

        if ([NSThread isMainThread])
        {
            attach();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), attach);
        }
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), attach);
    }

    void NativeChromeDetach()
    {
        auto detach = ^{
            [gNativeChrome detach];
            [gNativeChrome release];
            gNativeChrome = nil;
            gChromeLastParkOpen = -1;
            gChromeLastPaused = -1;
            gChromeLastSpeed = -1;
            gChromeLastFlags = 0xFFFFFFFFu;
            gChromeLastCash = kMoney64Undefined;
            gChromeLastGuests = 0xFFFFFFFFu;
            gChromeLastRating = 0xFFFFu;
            gChromeLastMonth = -1;
            gChromeLastDay = -1;
        };

        if ([NSThread isMainThread])
        {
            detach();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), detach);
        }
    }

    void NativeChromeTick()
    {
        if (gNativeChrome == nil)
        {
            return;
        }

        const int open = ParkIsOpen() ? 1 : 0;
        int paused = 0;
        int speed = 1;
        uint32_t flags = 0;
        money64 cashValue = kMoney64Undefined;
        uint32_t guestsValue = 0;
        uint16_t ratingValue = 0;
        int32_t monthValue = -1;
        int32_t dayValue = -1;
        NSString* cashText = nil;
        NSString* guestsText = nil;
        NSString* ratingText = nil;
        NSString* dateText = nil;
        if (open != 0)
        {
            paused = GameIsPaused() ? 1 : 0;
            speed = gGameSpeed;
            auto* mainWindow = WindowGetMain();
            if (mainWindow != nullptr && mainWindow->viewport != nullptr)
            {
                flags = mainWindow->viewport->flags;
            }

            const auto& gameState = getGameState();
            cashValue = gameState.park.cash;
            guestsValue = gameState.park.numGuestsInPark;
            ratingValue = gameState.park.rating;
            monthValue = gameState.date.GetMonth();
            dayValue = gameState.date.GetDay();
            cashText = [FormatParkCash(cashValue) retain];
            guestsText = [[NSString alloc] initWithFormat:@"%u", guestsValue];
            ratingText = [[NSString alloc] initWithFormat:@"%u", ratingValue];
            dateText = [FormatParkDate(gameState.date) retain];
        }

        const BOOL parkOpenChanged = open != gChromeLastParkOpen;
        const BOOL chromeStateChanged = paused != gChromeLastPaused || speed != gChromeLastSpeed || flags != gChromeLastFlags;
        const BOOL statusChanged = cashValue != gChromeLastCash || guestsValue != gChromeLastGuests
            || ratingValue != gChromeLastRating || monthValue != gChromeLastMonth || dayValue != gChromeLastDay;
        if (!parkOpenChanged && !chromeStateChanged && !statusChanged)
        {
            [cashText release];
            [guestsText release];
            [ratingText release];
            [dateText release];
            return;
        }

        gChromeLastParkOpen = open;
        gChromeLastPaused = paused;
        gChromeLastSpeed = speed;
        gChromeLastFlags = flags;
        gChromeLastCash = cashValue;
        gChromeLastGuests = guestsValue;
        gChromeLastRating = ratingValue;
        gChromeLastMonth = monthValue;
        gChromeLastDay = dayValue;

        auto sync = ^{
            if (parkOpenChanged)
            {
                [gNativeChrome setParkOpen:open != 0];
            }
            if (parkOpenChanged || chromeStateChanged)
            {
                [gNativeChrome updateParkChromeStatePaused:paused != 0 speed:static_cast<uint8_t>(speed) flags:flags];
            }
            if (open != 0 && (parkOpenChanged || statusChanged))
            {
                [gNativeChrome updateStatusCash:cashText guests:guestsText rating:ratingText date:dateText];
            }
            [cashText release];
            [guestsText release];
            [ratingText release];
            [dateText release];
        };
        if ([NSThread isMainThread])
        {
            sync();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), sync);
        }
    }

    bool NativeChromeHandleEvent(const SDL_Event& event)
    {
        if (gNativeChromeEventType == 0 || gNativeChromeEventType == static_cast<Uint32>(-1)
            || event.type != gNativeChromeEventType)
        {
            return false;
        }

        if (!ParkIsOpen())
        {
            return true;
        }

        const int32_t extra = static_cast<int32_t>(reinterpret_cast<intptr_t>(event.user.data1));
        WindowBase* mainWindow = nullptr;

        switch (event.user.code)
        {
            case kNativeChromeBuildNewRide:
                OpenRCT2::ContextOpenWindow(WindowClass::constructRide);
                break;
            case kNativeChromeTrees:
                Windows::ToggleSceneryWindow();
                break;
            case kNativeChromePaths:
                Windows::ToggleFootpathWindow();
                break;
            case kNativeChromeLand:
                Windows::ToggleLandWindow();
                break;
            case kNativeChromeWater:
                Windows::ToggleWaterWindow();
                break;
            case kNativeChromeClearScenery:
                Windows::ToggleClearSceneryWindow();
                break;
            case kNativeChromeRideList:
                OpenRCT2::ContextOpenWindow(WindowClass::rideList);
                break;
            case kNativeChromeParkInformation:
                OpenRCT2::ContextOpenWindow(WindowClass::parkInformation);
                break;
            case kNativeChromeStaffList:
                OpenRCT2::ContextOpenWindow(WindowClass::staffList);
                break;
            case kNativeChromeGuestList:
                OpenRCT2::ContextOpenWindow(WindowClass::guestList);
                break;
            case kNativeChromeFinances:
                OpenRCT2::ContextOpenWindow(WindowClass::finances);
                break;
            case kNativeChromeResearch:
                OpenRCT2::ContextOpenWindow(WindowClass::research);
                break;
            case kNativeChromeRecentNews:
                OpenRCT2::ContextOpenWindow(WindowClass::recentNews);
                break;
            case kNativeChromeMap:
                OpenRCT2::ContextOpenWindow(WindowClass::map);
                break;
            case kNativeChromeExtraViewport:
                OpenRCT2::ContextOpenWindow(WindowClass::viewport);
                break;
            case kNativeChromeViewClipping:
                OpenRCT2::ContextOpenWindow(WindowClass::viewClipping);
                break;
            case kNativeChromeTransparency:
                OpenRCT2::ContextOpenWindow(WindowClass::transparency);
                break;
            case kNativeChromeLoadSave:
                SaveGameAs();
                break;
            case kNativeChromeOptions:
                OpenRCT2::ContextOpenWindow(WindowClass::options);
                break;
            case kNativeChromeAbout:
                OpenRCT2::ContextOpenWindow(WindowClass::about);
                break;
            case kNativeChromeCheats:
                OpenRCT2::ContextOpenWindow(WindowClass::cheats);
                break;
            case kNativeChromeTileInspector:
                OpenRCT2::ContextOpenWindow(WindowClass::tileInspector);
                break;
            case kNativeChromePause:
                if (Network::GetMode() != Network::Mode::client)
                {
                    auto pauseToggleAction = GameActions::PauseToggleAction();
                    GameActions::Execute(&pauseToggleAction, getGameState());
                }
                break;
            case kNativeChromeGameSpeed:
                CycleGameSpeed();
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
            default:
                break;
        }
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked action %d", event.user.code);
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
