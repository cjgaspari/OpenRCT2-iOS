/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
#endif

namespace OpenRCT2::Ui
{
    /**
     * Single policy gate for desktop toolbars / info panels that the native
     * Liquid Glass park chrome replaces on iOS. Prefer this over scattered
     * `#if TARGET_OS_IOS return nullptr` blocks.
     */
    constexpr bool ShouldCreateDesktopChromeWindows()
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        return false;
#else
        return true;
#endif
    }
} // namespace OpenRCT2::Ui
