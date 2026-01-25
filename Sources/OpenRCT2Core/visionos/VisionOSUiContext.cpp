/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext (stub)
 ****************************************************************************/

#include <openrct2/drawing/X8DrawingEngine.h>
#include <openrct2/ui/WindowManager.h>
#include "VisionOSUiContext.h"

using namespace OpenRCT2::Drawing;

namespace OpenRCT2::Ui
{
    class VisionOSUiContext final : public IUiContext
    {
    private:
        std::unique_ptr<IWindowManager> const _windowManager = CreateDummyWindowManager();
        int32_t _width{1280};
        int32_t _height{720};

    public:
        void InitialiseScriptExtensions() override {}
        void Tick() override {}
        void Draw(RenderTarget& /*rt*/) override {}

        // Window
        void CreateWindow() override {}
        void CloseWindow() override {}
        void RecreateWindow() override {}
        void* GetWindow() override { return nullptr; }
        int32_t GetWidth() override { return _width; }
        int32_t GetHeight() override { return _height; }
        ScaleQuality GetScaleQuality() override { return ScaleQuality::NearestNeighbour; }
        void SetFullscreenMode(FullscreenMode /*mode*/) override {}
        const std::vector<Resolution>& GetFullscreenResolutions() override
        {
            static std::vector<Resolution> res;
            return res;
        }
        bool HasFocus() override { return true; }
        bool IsMinimised() override { return false; }
        bool IsSteamOverlayActive() override { return false; }
        void ProcessMessages() override {}
        void TriggerResize() override {}

        void ShowMessageBox(const std::string& /*message*/) override {}
        int32_t ShowMessageBox(const std::string&, const std::string&, const std::vector<std::string>&) override
        {
            return -1;
        }

        bool HasMenuSupport() override { return false; }
        int32_t ShowMenuDialog(
            const std::vector<std::string>& options, const std::string& /*title*/, const std::string& /*text*/) override
        {
            return options.empty() ? -1 : 0;
        }
        void OpenFolder(const std::string& /*path*/) override {}
        void OpenURL(const std::string& /*url*/) override {}
        std::string ShowFileDialog(const FileDialogDesc& /*desc*/) override { return std::string(); }
        std::string ShowDirectoryDialog(const std::string& /*title*/) override { return std::string(); }
        bool HasFilePicker() const override { return false; }

        // Input
        const CursorState* GetCursorState() override { return nullptr; }
        CursorID GetCursor() override { return CursorID::Arrow; }
        void SetCursor(CursorID /*cursor*/) override {}
        void SetCursorScale(uint8_t /*scale*/) override {}
        void SetCursorVisible(bool /*value*/) override {}
        ScreenCoordsXY GetCursorPosition() override { return {}; }
        void SetCursorPosition(const ScreenCoordsXY& /*cursorPosition*/) override {}
        void SetCursorTrap(bool /*value*/) override {}
        const uint8_t* GetKeysState() override { return nullptr; }
        const uint8_t* GetKeysPressed() override { return nullptr; }
        void SetKeysPressed(uint32_t /*keysym*/, uint8_t /*scancode*/) override {}

        class X8DrawingEngineFactory final : public IDrawingEngineFactory
        {
            std::unique_ptr<IDrawingEngine> Create([[maybe_unused]] DrawingEngine type, IUiContext& uiContext) override
            {
                return std::make_unique<X8DrawingEngine>(uiContext);
            }
        };

        // Drawing
        std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory() override
        {
            return std::make_shared<X8DrawingEngineFactory>();
        }
        void DrawWeatherAnimation(IWeatherDrawer* /*weatherDrawer*/, RenderTarget& /*rt*/, DrawWeatherFunc /*drawFunc*/) override {}

        // Text input
        bool IsTextInputActive() override { return false; }
        TextInputSession* StartTextInput([[maybe_unused]] u8string& buffer, [[maybe_unused]] size_t maxLength) override
        {
            return nullptr;
        }
        void StopTextInput() override {}

        // In-game UI
        IWindowManager* GetWindowManager() override { return _windowManager.get(); }

        // Clipboard
        bool SetClipboardText([[maybe_unused]] const utf8* target) override { return false; }

        ITitleSequencePlayer* GetTitleSequencePlayer() override { return nullptr; }
    };

    std::unique_ptr<IUiContext> CreateVisionOSUiContext()
    {
        return std::make_unique<VisionOSUiContext>();
    }
}
