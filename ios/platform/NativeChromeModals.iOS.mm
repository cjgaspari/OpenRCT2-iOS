/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"
#include "NativeChromeInternal.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #import <Foundation/Foundation.h>
    #include <UIKit/UIKit.h>

namespace OpenRCT2::Ui
{
    void NativeChromeScenarioPickerPresent(std::string_view snapshotJSON)
    {
        NSString* snapshot = [[NSString alloc] initWithBytes:snapshotJSON.data()
                                                      length:snapshotJSON.size()
                                                    encoding:NSUTF8StringEncoding];
        auto present = ^{
          [NativeChromeOverlayInstance() presentScenarioPicker:snapshot];
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
          [NativeChromeOverlayInstance() dismissScenarioPicker];
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
          [NativeChromeOverlayInstance() setScenarioPreviewLoading:loading scenarioID:scenarioID];
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
          [NativeChromeOverlayInstance() setScenarioPreview:data scenarioID:scenarioID width:width height:height];
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
          [NativeChromeOverlayInstance() presentLoadSave:snapshot];
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
          [NativeChromeOverlayInstance() dismissLoadSave];
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

    bool NativeChromeLoadSaveCopyPendingName(char* buffer, size_t length)
    {
        if (NativeChromeOverlayInstance() == nil || buffer == nullptr || length == 0)
        {
            return false;
        }
        return [NativeChromeOverlayInstance() copyPendingSaveName:buffer length:length] == YES;
    }

} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
