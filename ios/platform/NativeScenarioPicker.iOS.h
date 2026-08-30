/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstdint>
#include <functional>
#include <string_view>

namespace OpenRCT2
{
    struct WindowBase;
}

namespace OpenRCT2::Ui
{
    OpenRCT2::WindowBase* NativeScenarioPickerOpen(std::function<void(std::string_view)> callback);
    bool NativeScenarioPickerIsOpen();
    bool NativeScenarioPickerHandleAction(int32_t code, int32_t extra);
    void NativeScenarioPickerRefreshPresentation();
} // namespace OpenRCT2::Ui
