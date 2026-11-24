/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "NativeChromeOverlay.iOS.h"

namespace OpenRCT2::Ui
{
    OpenRCT2TouchNativeChrome* NativeChromeOverlayInstance();
} // namespace OpenRCT2::Ui

#endif
