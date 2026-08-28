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

namespace OpenRCT2::Ui
{
    struct IosSafeArea
    {
        float top = 0;
        float left = 0;
        float bottom = 0;
        float right = 0;
        float scale = 1;
        int32_t windowWidth = 0;
        int32_t windowHeight = 0;
    };

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
    IosSafeArea GetIosSafeArea();
    void RestoreIosCanvasFrame();
#endif
}
