/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #import <UIKit/UIKit.h>

struct SDL_Window;

namespace OpenRCT2::Ui
{
    /// Prefer the SDL UIKit window; otherwise the largest usable scene window.
    UIWindow* IOSUIKitWindowFromSdl(SDL_Window* window);
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
