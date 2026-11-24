/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChromeOverlay.iOS.h"

#include "NativeChrome.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "TouchLogging.iOS.h"
    #include "chrome/ParkChromeActions.h"

    #import <os/log.h>

@implementation OpenRCT2TouchNativeChrome {
    void* _session;
    UIView* _hostView;
    BOOL _parkOpen;
    NSString* _scenarioSnapshotJSON;
    NSString* _loadSaveSnapshotJSON;
}

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
        TOUCH_LOG_ERROR(@"[OpenRCT2Touch] native chrome: SwiftUI overlay attach failed");
        _hostView = nil;
        return;
    }

    TOUCH_LOG_INFO(@"[OpenRCT2Touch] native chrome: attached SwiftUI park overlay");
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
    OpenRCT2TouchChromeSetStatus(_session, cash.UTF8String, guests.UTF8String, rating.UTF8String, date.UTF8String);
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

- (void)setScenarioPreview:(NSData*)rgba scenarioID:(int32_t)scenarioID width:(int32_t)width height:(int32_t)height
{
    if (_session != nullptr)
    {
        OpenRCT2TouchChromeSetScenarioPreview(_session, scenarioID, static_cast<const uint8_t*>(rgba.bytes), width, height);
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

#endif // TARGET_OS_IOS
