/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <openrct2-ui/windows/Windows.h>

    #include <SDL.h>
    #include <SDL_syswm.h>
    #include <UIKit/UIKit.h>
    #include <cstdint>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/scenes/SceneManager.h>
    #include <openrct2/ui/WindowManager.h>
    #include <os/log.h>

namespace
{
    constexpr Sint32 kNativeChromeBuildNewRide = 1;
    constexpr Sint32 kNativeChromeTrees = 2;
    constexpr Sint32 kNativeChromePaths = 3;
    constexpr CGFloat kChromeSideButtonSize = 48.0;
    constexpr CGFloat kChromeRideButtonSize = 56.0;
    constexpr CGFloat kChromeButtonSpacing = 16.0;

    Uint32 gNativeChromeEventType = 0;

    Uint32 EnsureNativeChromeEventType()
    {
        if (gNativeChromeEventType == 0)
        {
            gNativeChromeEventType = SDL_RegisterEvents(1);
        }
        return gNativeChromeEventType;
    }

    UIImage* ChromeSymbol(NSString* name, CGFloat pointSize)
    {
        UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                                     weight:UIImageSymbolWeightSemibold];
        UIImage* image = [UIImage systemImageNamed:name withConfiguration:configuration];
        if (image == nil)
        {
            image = [UIImage systemImageNamed:name];
        }
        return image;
    }

    void QueueChromeAction(Sint32 code, const char* name)
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
        if (SDL_PushEvent(&event) != 1)
        {
            LOG_ERROR("[OpenRCT2Touch] native chrome: failed to queue %s action", name);
            return;
        }

        NSLog(@"[OpenRCT2Touch] native chrome: queued %s action", name);
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: queued %{public}s action", name);
    }
} // namespace

@interface OpenRCT2TouchNativeChrome : NSObject
{
    UIStackView* _cluster;
    UIButton* _treesButton;
    UIButton* _buildRideButton;
    UIButton* _pathsButton;
    UIView* _hostView;
}

- (void)attachToView:(UIView*)parent;
- (void)detach;
- (void)setParkOpen:(BOOL)open;

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

- (UIButton*)makeGlassButtonWithSymbol:(NSString*)symbolName
                        fallbackSymbol:(NSString*)fallbackSymbol
                            styleClear:(BOOL)styleClear
                                  size:(CGFloat)size
                            identifier:(NSString*)identifier
                                 label:(NSString*)label
                                action:(SEL)action
{
    UIImage* image = ChromeSymbol(symbolName, size > 50.0 ? 22.0 : 18.0);
    if (image == nil && fallbackSymbol != nil)
    {
        image = ChromeSymbol(fallbackSymbol, size > 50.0 ? 22.0 : 18.0);
    }

    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityIdentifier = identifier;
    button.accessibilityLabel = label;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIButtonConfiguration* config = nil;
    if (@available(iOS 26.0, *))
    {
        // Official UIKit Liquid Glass button styles. Clear for supporting
        // tools; prominent + blue tint for the primary construct-ride action.
        if (styleClear)
        {
            config = [UIButtonConfiguration clearGlassButtonConfiguration];
            config.baseForegroundColor = UIColor.labelColor;
        }
        else
        {
            config = [UIButtonConfiguration prominentGlassButtonConfiguration];
            config.baseBackgroundColor = UIColor.systemBlueColor;
            config.baseForegroundColor = UIColor.whiteColor;
        }
    }
    else if (styleClear)
    {
        config = [UIButtonConfiguration grayButtonConfiguration];
        config.baseForegroundColor = UIColor.labelColor;
    }
    else
    {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseBackgroundColor = UIColor.systemBlueColor;
        config.baseForegroundColor = UIColor.whiteColor;
    }

    config.image = image;
    config.title = nil;
    config.subtitle = nil;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.buttonSize = size > 50.0 ? UIButtonConfigurationSizeLarge : UIButtonConfigurationSizeMedium;
    config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);
    button.configuration = config;

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:size],
        [button.heightAnchor constraintEqualToConstant:size],
    ]];

    if ([identifier isEqualToString:@"openrct2.touch.buildRide"])
    {
        _buildRideButton = [button retain];
    }
    else if ([identifier isEqualToString:@"openrct2.touch.trees"])
    {
        _treesButton = [button retain];
    }
    else if ([identifier isEqualToString:@"openrct2.touch.paths"])
    {
        _pathsButton = [button retain];
    }

    return button;
}

- (void)attachToView:(UIView*)parent
{
    if (parent == nil)
    {
        return;
    }

    if (_cluster != nil && _hostView == parent && _cluster.superview == parent)
    {
        [parent bringSubviewToFront:_cluster];
        return;
    }

    [self detach];
    _hostView = parent;

    UIButton* trees = [self makeGlassButtonWithSymbol:@"tree.fill"
                                       fallbackSymbol:@"leaf.fill"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.trees"
                                                label:@"Trees"
                                               action:@selector(treesTapped)];
    UIButton* ride = [self makeGlassButtonWithSymbol:@"plus"
                                      fallbackSymbol:@"plus.circle.fill"
                                          styleClear:NO
                                                size:kChromeRideButtonSize
                                          identifier:@"openrct2.touch.buildRide"
                                               label:@"Build new ride or attraction"
                                              action:@selector(buildRideTapped)];
    UIButton* paths = [self makeGlassButtonWithSymbol:@"point.bottomleft.forward.to.point.topright.scurvepath"
                                       fallbackSymbol:@"road.lanes"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.paths"
                                                label:@"Paths"
                                               action:@selector(pathsTapped)];

    _cluster = [[UIStackView alloc] initWithArrangedSubviews:@[ trees, ride, paths ]];
    _cluster.translatesAutoresizingMaskIntoConstraints = NO;
    _cluster.axis = UILayoutConstraintAxisHorizontal;
    _cluster.alignment = UIStackViewAlignmentCenter;
    _cluster.spacing = kChromeButtonSpacing;
    _cluster.backgroundColor = UIColor.clearColor;
    _cluster.accessibilityIdentifier = @"openrct2.touch.nativeChrome";
    _cluster.hidden = YES;
    _cluster.userInteractionEnabled = NO;

    [parent addSubview:_cluster];
    [parent bringSubviewToFront:_cluster];
    [NSLayoutConstraint activateConstraints:@[
        [_cluster.centerXAnchor constraintEqualToAnchor:parent.centerXAnchor],
        [_cluster.bottomAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.bottomAnchor constant:-12],
    ]];

    NSLog(@"[OpenRCT2Touch] native chrome: attached park overlay");
    os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: attached park overlay");
}

- (void)detach
{
    [_treesButton removeTarget:self action:@selector(treesTapped) forControlEvents:UIControlEventTouchUpInside];
    [_treesButton release];
    _treesButton = nil;

    [_buildRideButton removeTarget:self action:@selector(buildRideTapped) forControlEvents:UIControlEventTouchUpInside];
    [_buildRideButton release];
    _buildRideButton = nil;

    [_pathsButton removeTarget:self action:@selector(pathsTapped) forControlEvents:UIControlEventTouchUpInside];
    [_pathsButton release];
    _pathsButton = nil;

    [_cluster removeFromSuperview];
    [_cluster release];
    _cluster = nil;
    _hostView = nil;
}

- (void)setParkOpen:(BOOL)open
{
    if (_cluster == nil)
    {
        return;
    }

    const BOOL wasHidden = _cluster.hidden;
    _cluster.hidden = !open;
    _cluster.userInteractionEnabled = open;
    if (open && _hostView != nil)
    {
        [_hostView bringSubviewToFront:_cluster];
    }
    if (wasHidden == open)
    {
        NSLog(@"[OpenRCT2Touch] native chrome: park overlay visible=%d", open ? 1 : 0);
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: park overlay visible=%{public}d", open ? 1 : 0);
    }
}

- (void)treesTapped
{
    QueueChromeAction(kNativeChromeTrees, "trees");
}

- (void)buildRideTapped
{
    QueueChromeAction(kNativeChromeBuildNewRide, "build-ride");
}

- (void)pathsTapped
{
    QueueChromeAction(kNativeChromePaths, "paths");
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    (void)notification;
    if (_cluster == nil || _cluster.superview == nil)
    {
        OpenRCT2::Ui::NativeChromeAttach(nullptr);
    }
    else if (_hostView != nil)
    {
        [_hostView bringSubviewToFront:_cluster];
    }
}

@end

namespace OpenRCT2::Ui
{
    namespace
    {
        OpenRCT2TouchNativeChrome* gNativeChrome = nil;
        int gChromeLastParkOpen = -1;

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
            // PreloaderScene also sets gLegacyScene to playing, so scene identity
            // is the park-open test. Hide on title, intro, editors, and loads.
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
        if (open == gChromeLastParkOpen)
        {
            return;
        }
        gChromeLastParkOpen = open;

        auto sync = ^{
            [gNativeChrome setParkOpen:open != 0];
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

        switch (event.user.code)
        {
            case kNativeChromeBuildNewRide:
                OpenRCT2::ContextOpenWindow(WindowClass::constructRide);
                os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked construct-ride window");
                break;
            case kNativeChromeTrees:
                Windows::ToggleSceneryWindow();
                os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked scenery window");
                break;
            case kNativeChromePaths:
                Windows::ToggleFootpathWindow();
                os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked footpath window");
                break;
            default:
                break;
        }
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
