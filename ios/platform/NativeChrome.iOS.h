/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

struct SDL_Window;
union SDL_Event;

namespace OpenRCT2::Ui
{
    void NativeChromeAttach(SDL_Window* window);
    void NativeChromeDetach();
    void NativeChromeTick();
    bool NativeChromeHandleEvent(const SDL_Event& event);
    void NativeChromeScenarioPickerPresent(std::string_view snapshotJSON);
    void NativeChromeScenarioPickerDismiss();
    void NativeChromeScenarioPickerSetPreviewLoading(int32_t scenarioID, bool loading);
    void NativeChromeScenarioPickerSetPreview(
        int32_t scenarioID, const uint8_t* rgba, size_t byteCount, int32_t width, int32_t height);
    void NativeChromeLoadSavePresent(std::string_view snapshotJSON);
    void NativeChromeLoadSaveDismiss();
    bool NativeChromeLoadSaveCopyPendingName(char* buffer, size_t length);
} // namespace OpenRCT2::Ui
