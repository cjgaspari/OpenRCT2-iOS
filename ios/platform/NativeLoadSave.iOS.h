/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstdint>
#include <functional>
#include <string_view>

struct TrackDesign;

namespace OpenRCT2
{
    enum class LoadSaveAction : uint8_t;
    enum class LoadSaveType : uint8_t;
    enum class ModalResult : int8_t;

    struct WindowBase;
} // namespace OpenRCT2

namespace OpenRCT2::Ui
{
    using NativeLoadSaveCallback = std::function<void(OpenRCT2::ModalResult, std::string_view)>;

    // Presents the native load/save sheet. Returns true if it took over the
    // request (always true on iOS); false to fall back to the built-in window.
    bool NativeLoadSaveOpen(
        OpenRCT2::LoadSaveAction action, OpenRCT2::LoadSaveType type, std::string_view defaultPath,
        NativeLoadSaveCallback callback, bool isJsCallback, TrackDesign* trackDesign);
    bool NativeLoadSaveIsOpen();
    bool NativeLoadSaveHandleAction(int32_t code, int32_t extra);
} // namespace OpenRCT2::Ui
