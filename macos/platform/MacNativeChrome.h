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

struct SDL_Window;
union SDL_Event;

namespace OpenRCT2::Ui
{
    void MacNativeChromeAttach(SDL_Window* window);
    void MacNativeChromeDetach();
    void MacNativeChromeTick();
    bool MacNativeChromeHandleEvent(const SDL_Event& event);
}

#endif // TARGET_OS_OSX
