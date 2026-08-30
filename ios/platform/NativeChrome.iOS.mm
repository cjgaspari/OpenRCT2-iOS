/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"
#include "NativeLoadSave.iOS.h"
#include "NativeScenarioPicker.iOS.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "chrome/ParkChromeActions.h"

    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>

    #include <SDL.h>
    #include <SDL_syswm.h>
    #include <UIKit/UIKit.h>
    #include <algorithm>
    #include <cstdint>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/GameSetSpeedAction.h>
    #include <openrct2/actions/general/LoadOrQuitAction.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/Date.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/interface/WindowTypes.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/localisation/Currency.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/scenes/SceneManager.h>
    #include <openrct2/ui/WindowManager.h>
    #include <openrct2/windows/Intent.h>
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
    NSString* _scenarioSnapshotJSON;
    NSString* _loadSaveSnapshotJSON;
}

- (void)attachToView:(UIView*)parent;
- (void)detach;
- (void)setParkOpen:(BOOL)open;
- (void)updateParkChromeStatePaused:(BOOL)paused speed:(uint8_t)speed flags:(uint32_t)flags;
- (void)updateStatusCash:(NSString*)cash guests:(NSString*)guests rating:(NSString*)rating date:(NSString*)date;
- (void)presentScenarioPicker:(NSString*)snapshotJSON;
- (void)dismissScenarioPicker;
- (void)setScenarioPreviewLoading:(BOOL)loading scenarioID:(int32_t)scenarioID;
- (void)setScenarioPreview:(NSData*)rgba scenarioID:(int32_t)scenarioID width:(int32_t)width height:(int32_t)height;
- (void)presentLoadSave:(NSString*)snapshotJSON;
- (void)dismissLoadSave;
- (BOOL)copyPendingSaveName:(char*)buffer length:(size_t)length;

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
    [_scenarioSnapshotJSON release];
    _scenarioSnapshotJSON = nil;
    [_loadSaveSnapshotJSON release];
    _loadSaveSnapshotJSON = nil;
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
    if (_scenarioSnapshotJSON != nil)
    {
        OpenRCT2TouchChromePresentScenarioPicker(_session, _scenarioSnapshotJSON.UTF8String);
    }
    if (_loadSaveSnapshotJSON != nil)
    {
        OpenRCT2TouchChromePresentLoadSave(_session, _loadSaveSnapshotJSON.UTF8String);
    }
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

- (void)presentScenarioPicker:(NSString*)snapshotJSON
{
    if (snapshotJSON == nil)
    {
        return;
    }
    [_scenarioSnapshotJSON release];
    _scenarioSnapshotJSON = [snapshotJSON copy];
    if (_session != nullptr)
    {
        OpenRCT2TouchChromePresentScenarioPicker(_session, _scenarioSnapshotJSON.UTF8String);
    }
}

- (void)dismissScenarioPicker
{
    [_scenarioSnapshotJSON release];
    _scenarioSnapshotJSON = nil;
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeDismissScenarioPicker(_session);
    }
}

- (void)setScenarioPreviewLoading:(BOOL)loading scenarioID:(int32_t)scenarioID
{
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeSetScenarioPreviewLoading(_session, scenarioID, loading);
    }
}

- (void)setScenarioPreview:(NSData*)rgba
                 scenarioID:(int32_t)scenarioID
                      width:(int32_t)width
                     height:(int32_t)height
{
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeSetScenarioPreview(
            _session, scenarioID, static_cast<const uint8_t*>(rgba.bytes), width, height);
    }
}

- (void)presentLoadSave:(NSString*)snapshotJSON
{
    if (snapshotJSON == nil)
    {
        return;
    }
    [_loadSaveSnapshotJSON release];
    _loadSaveSnapshotJSON = [snapshotJSON copy];
    if (_session != nullptr)
    {
        OpenRCT2TouchChromePresentLoadSave(_session, _loadSaveSnapshotJSON.UTF8String);
    }
}

- (void)dismissLoadSave
{
    [_loadSaveSnapshotJSON release];
    _loadSaveSnapshotJSON = nil;
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeDismissLoadSave(_session);
    }
}

- (BOOL)copyPendingSaveName:(char*)buffer length:(size_t)length
{
    if (_session == nullptr || buffer == nullptr || length == 0)
    {
        return NO;
    }
    return OpenRCT2TouchChromeCopyPendingSaveName(_session, buffer, static_cast<int32_t>(length));
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
            CGFloat bestArea = 0;
            auto consider = [&](BOOL requireOrientationMatch) {
                for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
                {
                    if (![scene isKindOfClass:UIWindowScene.class])
                    {
                        continue;
                    }

                    UIWindowScene* windowScene = static_cast<UIWindowScene*>(scene);
                    const CGSize sceneSize = windowScene.effectiveGeometry.coordinateSpace.bounds.size;
                    const BOOL landscape = sceneSize.width >= sceneSize.height;
                    for (UIWindow* candidate in windowScene.windows)
                    {
                        if (candidate.hidden || candidate.rootViewController == nil)
                        {
                            continue;
                        }

                        const CGFloat width = CGRectGetWidth(candidate.bounds);
                        const CGFloat height = CGRectGetHeight(candidate.bounds);
                        const BOOL matches = landscape ? (width >= height) : (height >= width);
                        if (requireOrientationMatch && !matches)
                        {
                            continue;
                        }
                        const CGFloat area = width * height;
                        if (area > bestArea)
                        {
                            bestArea = area;
                            fallback = candidate;
                        }
                    }
                }
            };
            consider(YES);
            if (fallback == nil)
            {
                consider(NO);
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
                || windowMgr->FindByClass(WindowClass::scenarioSelect) != nullptr || NativeScenarioPickerIsOpen())
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

    void NativeChromeScenarioPickerPresent(std::string_view snapshotJSON)
    {
        NSString* snapshot = [[NSString alloc] initWithBytes:snapshotJSON.data()
                                                      length:snapshotJSON.size()
                                                    encoding:NSUTF8StringEncoding];
        auto present = ^{
            [gNativeChrome presentScenarioPicker:snapshot];
            [snapshot release];
        };
        if ([NSThread isMainThread])
        {
            present();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), present);
        }
    }

    void NativeChromeScenarioPickerDismiss()
    {
        auto dismiss = ^{
            [gNativeChrome dismissScenarioPicker];
        };
        if ([NSThread isMainThread])
        {
            dismiss();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), dismiss);
        }
    }

    void NativeChromeScenarioPickerSetPreviewLoading(int32_t scenarioID, bool loading)
    {
        auto update = ^{
            [gNativeChrome setScenarioPreviewLoading:loading scenarioID:scenarioID];
        };
        if ([NSThread isMainThread])
        {
            update();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), update);
        }
    }

    void NativeChromeScenarioPickerSetPreview(
        int32_t scenarioID, const uint8_t* rgba, size_t byteCount, int32_t width, int32_t height)
    {
        NSData* data = rgba == nullptr || byteCount == 0 ? nil : [[NSData alloc] initWithBytes:rgba length:byteCount];
        auto update = ^{
            [gNativeChrome setScenarioPreview:data scenarioID:scenarioID width:width height:height];
            [data release];
        };
        if ([NSThread isMainThread])
        {
            update();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), update);
        }
    }

    void NativeChromeLoadSavePresent(std::string_view snapshotJSON)
    {
        NSString* snapshot = [[NSString alloc] initWithBytes:snapshotJSON.data()
                                                      length:snapshotJSON.size()
                                                    encoding:NSUTF8StringEncoding];
        auto present = ^{
            [gNativeChrome presentLoadSave:snapshot];
            [snapshot release];
        };
        if ([NSThread isMainThread])
        {
            present();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), present);
        }
    }

    void NativeChromeLoadSaveDismiss()
    {
        auto dismiss = ^{
            [gNativeChrome dismissLoadSave];
        };
        if ([NSThread isMainThread])
        {
            dismiss();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), dismiss);
        }
    }

    // Called on the main thread while handling a queued action, so reading the
    // SwiftUI model's pending filename does not race with the UI.
    bool NativeChromeLoadSaveCopyPendingName(char* buffer, size_t length)
    {
        if (gNativeChrome == nil || buffer == nullptr || length == 0)
        {
            return false;
        }
        return [gNativeChrome copyPendingSaveName:buffer length:length] == YES;
    }

    void NativeChromeTick()
    {
        if (gNativeChrome == nil)
        {
            return;
        }

#if TARGET_OS_SIMULATOR
        // Temporary visual-verification hook. Removed after the Xcode MCP
        // screenshots are captured.
        static bool didHandleScenarioPickerPreviewArgument = false;
        if (!didHandleScenarioPickerPreviewArgument
            && [[[NSProcessInfo processInfo] arguments] containsObject:@"--open-native-scenario-picker"])
        {
            didHandleScenarioPickerPreviewArgument = true;
            NativeScenarioPickerOpen([](std::string_view) {});
        }
#endif

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

        const int32_t extra = static_cast<int32_t>(reinterpret_cast<intptr_t>(event.user.data1));
        if (NativeScenarioPickerHandleAction(event.user.code, extra))
        {
            os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native scenario picker: invoked action %d", event.user.code);
            return true;
        }

        if (NativeLoadSaveHandleAction(event.user.code, extra))
        {
            os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native load/save: invoked action %d", event.user.code);
            return true;
        }

        if (!ParkIsOpen())
        {
            return true;
        }

        WindowBase* mainWindow = nullptr;

        switch (event.user.code)
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
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked action %d", event.user.code);
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
