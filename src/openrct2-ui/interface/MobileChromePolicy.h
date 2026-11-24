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
     * Single policy gate for desktop toolbars / info panels that native Liquid
     * Glass park chrome replaces. Prefer this over scattered
     * `#if TARGET_OS_IOS return nullptr` blocks.
     *
     * research/mac-liquid-glass: on macOS the AppKit/SwiftUI glass toolbar
     * replaces engine TopToolbar / info panels (same product intent as iOS
     * Touch, but a separate Mac-native host — not Catalyst).
     */
    constexpr bool ShouldCreateDesktopChromeWindows()
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        return false;
#elif defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX && defined(OPENRCT2_MAC_GLASS_REPLACE_TOOLBARS)
        // Opt-in: research glass replaces engine toolbars when this define is set.
        return false;
#else
        return true;
#endif

    }
} // namespace OpenRCT2::Ui
