/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

struct SDL_Window;
union SDL_Event;

namespace OpenRCT2::Ui
{
    void NativeChromeAttach(SDL_Window* window);
    void NativeChromeDetach();
    void NativeChromeTick();
    bool NativeChromeHandleEvent(const SDL_Event& event);
}
