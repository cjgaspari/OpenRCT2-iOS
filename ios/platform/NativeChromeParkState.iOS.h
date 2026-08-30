/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstdint>
#include <openrct2/core/Money.hpp>

namespace OpenRCT2::Ui
{
    struct NativeChromeParkStateSnapshot
    {
        int Open = 0;
        int Paused = 0;
        int Speed = 1;
        uint32_t ViewportFlags = 0;
        money64 Cash = kMoney64Undefined;
        uint32_t Guests = 0;
        uint16_t Rating = 0;
        int32_t Month = -1;
        int32_t Day = -1;

        constexpr bool operator==(const NativeChromeParkStateSnapshot&) const = default;
    };

    bool NativeChromeParkIsOpen();
    NativeChromeParkStateSnapshot NativeChromeCaptureParkStateSnapshot();
} // namespace OpenRCT2::Ui
