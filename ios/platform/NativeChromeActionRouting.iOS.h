/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstdint>

namespace OpenRCT2::Ui
{
    const char* NativeChromeActionLogName(int32_t code);
    bool NativeChromeRouteParkAction(int32_t code, int32_t extra);
} // namespace OpenRCT2::Ui
