/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "MacCocoaWindow.h"

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

    #include <SDL.h>
    #include <SDL_syswm.h>

namespace OpenRCT2::Ui
{
    NSWindow* MacCocoaWindowFromSdl(SDL_Window* window)
    {
        if (window == nullptr)
        {
            return nil;
        }

        SDL_SysWMinfo windowInfo = {};
        SDL_VERSION(&windowInfo.version);
        if (SDL_GetWindowWMInfo(window, &windowInfo) != SDL_TRUE)
        {
            return nil;
        }
        if (windowInfo.subsystem != SDL_SYSWM_COCOA)
        {
            return nil;
        }
        return windowInfo.info.cocoa.window;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_OSX
