/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include "UiContext.h"

#ifdef OPENRCT2_VISIONOS

    #include <memory>

namespace OpenRCT2::Ui
{
    class DummyUiContext final : public IUiContext
    {
    private:
        int32_t _width = 1280;
        int32_t _height = 720;
        bool _hasFocus = true;
        ScaleQuality _scaleQuality = ScaleQuality::NearestNeighbour;
        bool _windowCreated = false;

    public:
        DummyUiContext();

        void InitialiseScriptExtensions() override;
        void Tick() override;
        void Draw(RenderTarget& rt) override;
        void* GetWindow() override;
        int32_t GetWidth() override;
        int32_t GetHeight() override;
        ScaleQuality GetScaleQuality() override;
        void SetFullscreenMode(FullscreenMode mode) override;
        const std::vector<Resolution>& GetFullscreenResolutions() override;
        bool HasFocus() override;
        bool IsMinimised() override;
        bool IsSteamOverlayActive() override;
        const CursorState* GetCursorState() override;
        const uint8_t* GetKeysState() override;
        const uint8_t* GetKeysPressed() override;
        CursorID GetCursor() override;
        void SetCursor(CursorID cursor) override;
        void SetCursorScale(uint8_t scale) override;
        void SetCursorVisible(bool value) override;
        ScreenCoordsXY GetCursorPosition() override;
        void SetCursorPosition(const ScreenCoordsXY& cursorPosition) override;
        void SetCursorTrap(bool value) override;
        void SetKeysPressed(uint32_t keysym, uint8_t scancode) override;
        std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory() override;
        void DrawWeatherAnimation(IWeatherDrawer* weatherDrawer, RenderTarget& rt, DrawWeatherFunc drawFunc) override;
        bool IsTextInputActive() override;
        TextInputSession* StartTextInput(u8string& buffer, size_t maxLength) override;
        void StopTextInput() override;
        void ProcessMessages() override;
        void TriggerResize() override;
        void CreateWindow() override;
        void CloseWindow() override;
        void RecreateWindow() override;
        void ShowMessageBox(const std::string& message) override;
        int32_t ShowMessageBox(
            const std::string& title, const std::string& message, const std::vector<std::string>& options) override;
        bool HasMenuSupport() override;
        int32_t ShowMenuDialog(
            const std::vector<std::string>& options, const std::string& title, const std::string& text) override;
        void OpenFolder(const std::string& path) override;
        void OpenURL(const std::string& url) override;
        std::string ShowFileDialog(const FileDialogDesc& desc) override;
        std::string ShowDirectoryDialog(const std::string& title) override;
        bool HasFilePicker() const override;
        IWindowManager* GetWindowManager() override;
    };

    std::unique_ptr<IUiContext> CreateDummyUiContext();
} // namespace OpenRCT2::Ui

#endif // OPENRCT2_VISIONOS