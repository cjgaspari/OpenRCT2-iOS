/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "IOSUIKitWindow.iOS.h"

#if TARGET_OS_IOS

    #include <SDL.h>
    #include <SDL_syswm.h>

namespace OpenRCT2::Ui
{
    UIWindow* IOSUIKitWindowFromSdl(SDL_Window* window)
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
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
