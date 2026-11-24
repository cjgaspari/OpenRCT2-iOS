/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"

#include "IOSUIKitWindow.iOS.h"
#include "NativeChromeActionRouting.iOS.h"
#include "NativeChromeOverlay.iOS.h"
#include "NativeChromeInternal.iOS.h"
#include "NativeChromeParkState.iOS.h"
#include "NativeLoadSave.iOS.h"
#include "NativeScenarioPicker.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "TouchLogging.iOS.h"
    #include "chrome/ParkChromeActions.h"

    #include <SDL.h>
    #include <UIKit/UIKit.h>
    #include <cstdint>
    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>
    #include <openrct2/Context.h>
    #include <openrct2/Date.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/localisation/Currency.h>
    #include <os/log.h>

namespace
{
    Uint32 _nativeChromeEventType = 0;

    Uint32 EnsureNativeChromeEventType()
    {
        if (_nativeChromeEventType == 0)
        {
            _nativeChromeEventType = SDL_RegisterEvents(1);
        }
        return _nativeChromeEventType;
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

        TOUCH_LOG_INFO(@"[OpenRCT2Touch] native chrome: queued %s action", name);
    }

    NSString* FormatParkCash(money64 cash)
    {
        char amount[OpenRCT2::kMoneyStringMaxlength];
        OpenRCT2::MoneyToString(cash, amount, sizeof(amount), false);
        const auto& currency = OpenRCT2::CurrencyDescriptors[EnumValue(OpenRCT2::Config::Get().general.currencyFormat)];
        if (currency.affix_unicode == OpenRCT2::CurrencyAffix::prefix)
        {
            return [NSString stringWithFormat:@"%s%s", currency.symbol_unicode, amount];
        }
        return [NSString stringWithFormat:@"%s%s", amount, currency.symbol_unicode];
    }

    NSString* FormatParkDate(int32_t month, int32_t day)
    {
        static NSString* const kMonthNames[] = {
            @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct",
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

// OpenRCT2TouchNativeChrome lives in NativeChromeOverlay.iOS.mm

namespace OpenRCT2::Ui
{
    static OpenRCT2TouchNativeChrome* _nativeChromeInstance = nil;

    OpenRCT2TouchNativeChrome* NativeChromeOverlayInstance()
    {
        return _nativeChromeInstance;
    }

    namespace
    {
        bool _chromeHasLastState = false;
        NativeChromeParkStateSnapshot _chromeLastState{};

        void AttachOnMainThread(SDL_Window* window)
        {
            if (_nativeChromeInstance == nil)
            {
                _nativeChromeInstance = [OpenRCT2TouchNativeChrome new];
            }

            UIWindow* host = IOSUIKitWindowFromSdl(window);
            UIView* parent = host.rootViewController.view;
            if (host == nil || parent == nil)
            {
                TOUCH_LOG_INFO(@"[OpenRCT2Touch] native chrome: no UIKit window yet");
                return;
            }

            [_nativeChromeInstance attachToView:parent];
            _chromeHasLastState = false;
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
          [_nativeChromeInstance detach];
          [_nativeChromeInstance release];
          _nativeChromeInstance = nil;
          _chromeHasLastState = false;
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

    // Called on the main thread while handling a queued action, so reading the
    // SwiftUI model's pending filename does not race with the UI.

    void NativeChromeTick()
    {
        if (_nativeChromeInstance == nil)
        {
            return;
        }

    #if TARGET_OS_SIMULATOR
        // Temporary visual-verification hook. Removed after the Xcode MCP
        // screenshots are captured.
        static bool didHandleScenarioPickerPreviewArgument = false;
        if (!didHandleScenarioPickerPreviewArgument &&
            [[[NSProcessInfo processInfo] arguments] containsObject:@"--open-native-scenario-picker"])
        {
            didHandleScenarioPickerPreviewArgument = true;
            NativeScenarioPickerOpen([](std::string_view) {});
        }
    #endif

        const NativeChromeParkStateSnapshot state = NativeChromeCaptureParkStateSnapshot();
        const BOOL parkOpenChanged = !_chromeHasLastState || state.Open != _chromeLastState.Open;
        const BOOL chromeStateChanged = !_chromeHasLastState || state.Paused != _chromeLastState.Paused
            || state.Speed != _chromeLastState.Speed || state.ViewportFlags != _chromeLastState.ViewportFlags;
        const BOOL statusChanged = !_chromeHasLastState || state.Cash != _chromeLastState.Cash
            || state.Guests != _chromeLastState.Guests || state.Rating != _chromeLastState.Rating
            || state.Month != _chromeLastState.Month || state.Day != _chromeLastState.Day;
        if (!parkOpenChanged && !chromeStateChanged && !statusChanged)
        {
            return;
        }
        _chromeLastState = state;
        _chromeHasLastState = true;

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
              [_nativeChromeInstance setParkOpen:state.Open != 0];
          }
          if (parkOpenChanged || chromeStateChanged)
          {
              [_nativeChromeInstance updateParkChromeStatePaused:state.Paused != 0
                                                           speed:static_cast<uint8_t>(state.Speed)
                                                           flags:state.ViewportFlags];
          }
          if (state.Open != 0 && (parkOpenChanged || statusChanged))
          {
              [_nativeChromeInstance updateStatusCash:cashText guests:guestsText rating:ratingText date:dateText];
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
        if (_nativeChromeEventType == 0 || _nativeChromeEventType == static_cast<Uint32>(-1)
            || event.type != _nativeChromeEventType)
        {
            return false;
        }

        const int32_t extra = static_cast<int32_t>(reinterpret_cast<intptr_t>(event.user.data1));
        if (NativeScenarioPickerHandleAction(event.user.code, extra))
        {
            TOUCH_OS_LOG_INFO("[OpenRCT2Touch] native scenario picker: invoked action %d", event.user.code);
            return true;
        }

        if (NativeLoadSaveHandleAction(event.user.code, extra))
        {
            TOUCH_OS_LOG_INFO("[OpenRCT2Touch] native load/save: invoked action %d", event.user.code);
            return true;
        }
        if (NativeChromeRouteParkAction(event.user.code, extra))
        {
            TOUCH_OS_LOG_INFO("[OpenRCT2Touch] native chrome: invoked action %d", event.user.code);
        }
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
