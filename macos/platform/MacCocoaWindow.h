/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

    #import <AppKit/AppKit.h>

struct SDL_Window;

namespace OpenRCT2::Ui
{
    /// Resolve the AppKit window that owns SDL's Metal/OpenGL content view.
    NSWindow* MacCocoaWindowFromSdl(SDL_Window* window);
}

#endif // TARGET_OS_OSX
