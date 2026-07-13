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
}

@end
