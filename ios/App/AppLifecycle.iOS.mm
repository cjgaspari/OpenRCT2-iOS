/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#import <UIKit/UIKit.h>

@interface OpenRCT2TouchLifecycleLogger : NSObject
@end

@implementation OpenRCT2TouchLifecycleLogger

+ (void)load
{
    static OpenRCT2TouchLifecycleLogger* logger;
    logger = [OpenRCT2TouchLifecycleLogger new];

    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    NSArray<NSNotificationName>* notifications = @[
        UIApplicationDidBecomeActiveNotification,
        UIApplicationWillResignActiveNotification,
        UIApplicationDidEnterBackgroundNotification,
        UIApplicationWillEnterForegroundNotification,
        UIApplicationDidReceiveMemoryWarningNotification,
        UIApplicationWillTerminateNotification,
    ];
    for (NSNotificationName name in notifications)
    {
        [center addObserver:logger selector:@selector(logLifecycle:) name:name object:nil];
    }

    NSLog(@"[OpenRCT2Touch] lifecycle: process-loaded");
}

- (void)logLifecycle:(NSNotification*)notification
{
    NSLog(@"[OpenRCT2Touch] lifecycle: %@", notification.name);

    if ([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow* activeWindow = nil;
            for (UIScene* scene in [UIApplication sharedApplication].connectedScenes)
            {
                if (![scene isKindOfClass:[UIWindowScene class]])
                {
                    continue;
                }

                for (UIWindow* window in ((UIWindowScene*)scene).windows)
                {
                    if (window.isKeyWindow)
                    {
                        activeWindow = window;
                        break;
                    }
                }
                if (activeWindow != nil)
                {
                    break;
                }
            }

            if (activeWindow != nil)
            {
                const CGRect bounds = activeWindow.bounds;
                const UIEdgeInsets insets = activeWindow.safeAreaInsets;
                const BOOL statusBarHidden = activeWindow.windowScene.statusBarManager.statusBarHidden;
                NSLog(
                    @"[OpenRCT2Touch] safe-area: bounds_points=%.0fx%.0f insets_points=top:%.0f,left:%.0f,bottom:%.0f,right:%.0f scale=%.2f status_bar_hidden=%d",
                    CGRectGetWidth(bounds), CGRectGetHeight(bounds), insets.top, insets.left, insets.bottom, insets.right,
                    activeWindow.traitCollection.displayScale, statusBarHidden);
            }

            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSFileManager* fileManager = [NSFileManager defaultManager];
                NSString* documentsPath = NSSearchPathForDirectoriesInDomains(
                    NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
                NSString* supportPath = NSSearchPathForDirectoriesInDomains(
                    NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
                NSString* cachesPath = NSSearchPathForDirectoriesInDomains(
                    NSCachesDirectory, NSUserDomainMask, YES).firstObject;
                NSLog(
                    @"[OpenRCT2Touch] sandbox: bundle_role=read_only documents_writable=%d support_writable=%d caches_writable=%d",
                    [fileManager isWritableFileAtPath:documentsPath], [fileManager isWritableFileAtPath:supportPath],
                    [fileManager isWritableFileAtPath:cachesPath]);
                NSLog(
                    @"[OpenRCT2Touch] paths: documents=%@ support=%@ caches=%@",
                    documentsPath, supportPath, cachesPath);
            });
        });
    }
}

@end
