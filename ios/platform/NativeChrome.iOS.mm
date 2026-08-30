/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"
#include "NativeChromeActionRouting.iOS.h"
#include "NativeLoadSave.iOS.h"
#include "NativeChromeParkState.iOS.h"
#include "NativeScenarioPicker.iOS.h"
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
    #include <openrct2/Date.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/localisation/Currency.h>
    #include <os/log.h>

@class OpenRCT2TouchNativeChrome;

namespace
{
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

    NSString* FormatParkDate(int32_t month, int32_t day)
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
        if (month < 0)
        {
            month = 0;
        }
        else if (month >= MONTH_COUNT)
        {
            month = MONTH_COUNT - 1;
        }
        return [NSString stringWithFormat:@"%@ %d", kMonthNames[month], day + 1];
    }

} // namespace

extern "C" void OpenRCT2TouchChromeHandleAction(int32_t code, int32_t extra)
{
    QueueChromeAction(code, OpenRCT2::Ui::NativeChromeActionLogName(code), extra);
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
        bool gChromeHasLastState = false;
        NativeChromeParkStateSnapshot gChromeLastState{};

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
            gChromeHasLastState = false;
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
            gChromeHasLastState = false;
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

        const NativeChromeParkStateSnapshot state = NativeChromeCaptureParkStateSnapshot();
        const BOOL parkOpenChanged = !gChromeHasLastState || state.Open != gChromeLastState.Open;
        const BOOL chromeStateChanged = !gChromeHasLastState || state.Paused != gChromeLastState.Paused
            || state.Speed != gChromeLastState.Speed || state.ViewportFlags != gChromeLastState.ViewportFlags;
        const BOOL statusChanged = !gChromeHasLastState || state.Cash != gChromeLastState.Cash
            || state.Guests != gChromeLastState.Guests || state.Rating != gChromeLastState.Rating
            || state.Month != gChromeLastState.Month || state.Day != gChromeLastState.Day;
        if (!parkOpenChanged && !chromeStateChanged && !statusChanged)
        {
            return;
        }
        gChromeLastState = state;
        gChromeHasLastState = true;

        NSString* cashText = nil;
        NSString* guestsText = nil;
        NSString* ratingText = nil;
        NSString* dateText = nil;
        if (state.Open != 0)
        {
            cashText = [FormatParkCash(state.Cash) retain];
            guestsText = [[NSString alloc] initWithFormat:@"%u", state.Guests];
            ratingText = [[NSString alloc] initWithFormat:@"%u", state.Rating];
            dateText = [FormatParkDate(state.Month, state.Day) retain];
        }

        auto sync = ^{
            if (parkOpenChanged)
            {
                [gNativeChrome setParkOpen:state.Open != 0];
            }
            if (parkOpenChanged || chromeStateChanged)
            {
                [gNativeChrome updateParkChromeStatePaused:state.Paused != 0
                                                     speed:static_cast<uint8_t>(state.Speed)
                                                     flags:state.ViewportFlags];
            }
            if (state.Open != 0 && (parkOpenChanged || statusChanged))
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
        if (NativeChromeRouteParkAction(event.user.code, extra))
        {
            os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked action %d", event.user.code);
        }
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
