/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstdint>

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX
extern "C" {
/** UI Lab `parkChrome` — true ⇒ create classic engine toolbars. */
bool OpenRCT2MacShouldCreateDesktopChromeWindows(void);
/** Top inset for glass HUD; 0 when classic toolbars are active. */
int32_t OpenRCT2MacLiquidGlassChromeTopInset(void);
}
#endif

namespace OpenRCT2::Ui
{
    /**
     * Single policy gate for desktop toolbars / info panels that native Liquid
     * Glass park chrome replaces. Prefer this over scattered
     * `#if TARGET_OS_IOS return nullptr` blocks.
     *
     * research/mac-liquid-glass: on macOS the AppKit/SwiftUI glass toolbar
     * replaces engine TopToolbar / info panels unless UI Lab disables parkChrome.
     */
    inline bool ShouldCreateDesktopChromeWindows()
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        return false;
#elif defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX
        return OpenRCT2MacShouldCreateDesktopChromeWindows();
#else
        return true;
#endif
    }

    /**
     * Top inset (engine pixels) reserved for Mac Option 1 Liquid Glass dual-top
     * capsules when engine TopToolbar is suppressed. Must stay in sync with
     * `WindowGetTopToolbarOffset()` on TARGET_OS_OSX.
     */
    inline int32_t MacLiquidGlassChromeTopInset()
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX
        return OpenRCT2MacLiquidGlassChromeTopInset();
#else
        return 0;
#endif
    }
} // namespace OpenRCT2::Ui
