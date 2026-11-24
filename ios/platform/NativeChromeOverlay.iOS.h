/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #import <UIKit/UIKit.h>
    #include <cstddef>
    #include <cstdint>

@interface OpenRCT2TouchNativeChrome : NSObject

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

#endif // TARGET_OS_IOS
