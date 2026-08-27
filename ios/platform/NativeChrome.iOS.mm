/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <SDL.h>
    #include <SDL_syswm.h>
    #include <UIKit/UIKit.h>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <os/log.h>

namespace
{
    constexpr Sint32 kNativeChromeBuildNewRide = 1;

    Uint32 gNativeChromeEventType = 0;

    Uint32 EnsureNativeChromeEventType()
    {
        if (gNativeChromeEventType == 0)
        {
            gNativeChromeEventType = SDL_RegisterEvents(1);
        }
        return gNativeChromeEventType;
    }
} // namespace

@interface OpenRCT2TouchNativeChrome : NSObject
{
    UIVisualEffectView* _bar;
    UIButton* _buildRideButton;
    UIView* _hostView;
}

- (void)attachToView:(UIView*)parent;
- (void)detach;
- (void)buildRideTapped;

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

    if (_bar != nil && _hostView == parent && _bar.superview == parent)
    {
        [parent bringSubviewToFront:_bar];
        return;
    }

    [self detach];
    _hostView = parent;

    UIBlurEffect* blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
    _bar = [[UIVisualEffectView alloc] initWithEffect:blur];
    _bar.translatesAutoresizingMaskIntoConstraints = NO;
    _bar.accessibilityIdentifier = @"openrct2.touch.nativeChrome";

    _buildRideButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
    _buildRideButton.translatesAutoresizingMaskIntoConstraints = NO;
    _buildRideButton.accessibilityIdentifier = @"openrct2.touch.buildRide";
    _buildRideButton.accessibilityLabel = @"Build new ride or attraction";

    UIButtonConfiguration* config = [UIButtonConfiguration filledButtonConfiguration];
    config.title = @"Build ride";
    config.image = [UIImage systemImageNamed:@"plus.circle.fill"];
    config.imagePadding = 8;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.contentInsets = NSDirectionalEdgeInsetsMake(10, 18, 10, 18);
    _buildRideButton.configuration = config;
    [_buildRideButton addTarget:self action:@selector(buildRideTapped) forControlEvents:UIControlEventTouchUpInside];

    [_bar.contentView addSubview:_buildRideButton];
    [parent addSubview:_bar];
    [parent bringSubviewToFront:_bar];

    [NSLayoutConstraint activateConstraints:@[
        [_bar.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
        [_bar.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
        [_bar.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor],
        [_buildRideButton.topAnchor constraintEqualToAnchor:_bar.contentView.topAnchor constant:10],
        [_buildRideButton.bottomAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [_buildRideButton.centerXAnchor constraintEqualToAnchor:_bar.contentView.centerXAnchor],
        [_buildRideButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:_bar.contentView.leadingAnchor constant:16],
        [_buildRideButton.trailingAnchor constraintLessThanOrEqualToAnchor:_bar.contentView.trailingAnchor constant:-16],
        [_buildRideButton.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    NSLog(@"[OpenRCT2Touch] native chrome: attached build-ride overlay");
    os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: attached build-ride overlay");
}

- (void)detach
{
    [_buildRideButton removeTarget:self action:@selector(buildRideTapped) forControlEvents:UIControlEventTouchUpInside];
    [_buildRideButton removeFromSuperview];
    [_buildRideButton release];
    _buildRideButton = nil;

    [_bar removeFromSuperview];
    [_bar release];
    _bar = nil;
    _hostView = nil;
}

- (void)buildRideTapped
{
    const Uint32 eventType = EnsureNativeChromeEventType();
    if (eventType == 0 || eventType == static_cast<Uint32>(-1))
    {
        LOG_ERROR("[OpenRCT2Touch] native chrome: SDL user event registration failed");
        return;
    }

    SDL_Event event{};
    event.type = eventType;
    event.user.code = kNativeChromeBuildNewRide;
    if (SDL_PushEvent(&event) != 1)
    {
        LOG_ERROR("[OpenRCT2Touch] native chrome: failed to queue build-ride action");
        return;
    }

    LOG_INFO("[OpenRCT2Touch] native chrome: queued build-ride action");
    NSLog(@"[OpenRCT2Touch] native chrome: queued build-ride action");
    os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: queued build-ride action");
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    (void)notification;
    if (_bar == nil || _bar.superview == nil)
    {
        OpenRCT2::Ui::NativeChromeAttach(nullptr);
    }
    else if (_hostView != nil)
    {
        [_hostView bringSubviewToFront:_bar];
    }
}

@end

namespace OpenRCT2::Ui
{
    namespace
    {
        OpenRCT2TouchNativeChrome* gNativeChrome = nil;

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
        NSLog(@"[OpenRCT2Touch] native chrome: attach requested");
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: attach requested");

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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), attach);
    }

    void NativeChromeDetach()
    {
        auto detach = ^{
            [gNativeChrome detach];
            [gNativeChrome release];
            gNativeChrome = nil;
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

    bool NativeChromeHandleEvent(const SDL_Event& event)
    {
        if (gNativeChromeEventType == 0 || gNativeChromeEventType == static_cast<Uint32>(-1)
            || event.type != gNativeChromeEventType)
        {
            return false;
        }

        if (event.user.code != kNativeChromeBuildNewRide)
        {
            return true;
        }

        // Same intent as the hidden top-toolbar construct-ride button.
        OpenRCT2::ContextOpenWindow(WindowClass::constructRide);
        LOG_INFO("[OpenRCT2Touch] native chrome: invoked construct-ride window");
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked construct-ride window");
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
