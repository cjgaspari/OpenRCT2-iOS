/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext (stub)
 ****************************************************************************/

#include "VisionOSUiContext.h"

#include <chrono>
#include <openrct2/drawing/X8DrawingEngine.h>
#include <openrct2/ui/WindowManager.h>

using namespace OpenRCT2::Drawing;

namespace OpenRCT2
{
    namespace Ui
    {
    class VisionOSUiContext final : public IUiContext
    {
    private:
        std::unique_ptr<IWindowManager> const _windowManager = CreateDummyWindowManager();
        int32_t _width{ 1280 };
        int32_t _height{ 720 };
        std::unique_ptr<X8DrawingEngine> _engine;
        std::chrono::steady_clock::time_point _lastTick{};

    public:
        void InitialiseScriptExtensions() override
        {
        }
        void Tick() override
        {
        }
        void Draw(RenderTarget& /*rt*/) override
        {
            if (!_engine)
            {
                _engine = std::make_unique<X8DrawingEngine>(*this);
                _engine->Initialise();
                _engine->Resize(static_cast<uint32_t>(_width), static_cast<uint32_t>(_height));

                // Create a simple palette gradient
                GamePalette pal{};
                for (size_t i = 0; i < pal.size(); ++i)
                {
                    pal[i].blue = static_cast<uint8_t>(i);
                    pal[i].green = static_cast<uint8_t>((i * 2) % 256);
                    pal[i].red = static_cast<uint8_t>((255 - i));
                    pal[i].alpha = 255;
                }
                _engine->SetPalette(pal);
            }

            _engine->BeginDraw();
            auto* dc = static_cast<X8DrawingContext*>(_engine->GetDrawingContext());
            auto* rt = _engine->getRT();
            dc->Clear(*rt, PaletteIndex::pi10);
            dc->FillRect(*rt, PaletteIndex::pi4, 50, 50, _width - 50, _height - 50, false);
            _engine->EndDraw();
        }

        // Window
        void CreateWindow() override
        {
        }
        void CloseWindow() override
        {
        }
        void RecreateWindow() override
        {
        }
        void* GetWindow() override
        {
            return nullptr;
        }
        int32_t GetWidth() override
        {
            return _width;
        }
        int32_t GetHeight() override
        {
            return _height;
        }
        ScaleQuality GetScaleQuality() override
        {
            return ScaleQuality::NearestNeighbour;
        }
        void SetFullscreenMode(FullscreenMode /*mode*/) override
        {
        }
        const std::vector<Resolution>& GetFullscreenResolutions() override
        {
            static std::vector<Resolution> res;
            return res;
        }
        bool HasFocus() override
        {
            return true;
        }
        bool IsMinimised() override
        {
            return false;
        }
        bool IsSteamOverlayActive() override
        {
            return false;
        }
        void ProcessMessages() override
        {
            // Simple ~40 Hz tick pacing for game loop stubs
            auto now = std::chrono::steady_clock::now();
            if (_lastTick.time_since_epoch().count() == 0)
            {
                _lastTick = now;
            }
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - _lastTick).count();
            if (elapsed >= 25)
            {
                Tick();
                _lastTick = now;
            }
        }
        void TriggerResize() override
        {
        }

        void ShowMessageBox(const std::string& /*message*/) override
        {
        }
        int32_t ShowMessageBox(const std::string&, const std::string&, const std::vector<std::string>&) override
        {
            return -1;
        }

        bool HasMenuSupport() override
        {
            return false;
        }
        int32_t ShowMenuDialog(
            const std::vector<std::string>& options, const std::string& /*title*/, const std::string& /*text*/) override
        {
            return options.empty() ? -1 : 0;
        }
        void OpenFolder(const std::string& /*path*/) override
        {
        }
        void OpenURL(const std::string& /*url*/) override
        {
        }
        std::string ShowFileDialog(const FileDialogDesc& /*desc*/) override
        {
            return std::string();
        }
        std::string ShowDirectoryDialog(const std::string& /*title*/) override
        {
            return std::string();
        }
        bool HasFilePicker() const override
        {
            return false;
        }

        // Input
        const CursorState* GetCursorState() override
        {
            return nullptr;
        }
        CursorID GetCursor() override
        {
            return CursorID::Arrow;
        }
        void SetCursor(CursorID /*cursor*/) override
        {
        }
        void SetCursorScale(uint8_t /*scale*/) override
        {
        }
        void SetCursorVisible(bool /*value*/) override
        {
        }
        ScreenCoordsXY GetCursorPosition() override
        {
            return {};
        }
        void SetCursorPosition(const ScreenCoordsXY& /*cursorPosition*/) override
        {
        }
        void SetCursorTrap(bool /*value*/) override
        {
        }
        const uint8_t* GetKeysState() override
        {
            return nullptr;
        }
        const uint8_t* GetKeysPressed() override
        {
            return nullptr;
        }
        void SetKeysPressed(uint32_t /*keysym*/, uint8_t /*scancode*/) override
        {
        }

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
        void DrawWeatherAnimation(
            IWeatherDrawer* /*weatherDrawer*/, RenderTarget& /*rt*/, DrawWeatherFunc /*drawFunc*/) override
        {
        }

        // Text input
        bool IsTextInputActive() override
        {
            return false;
        }
        TextInputSession* StartTextInput([[maybe_unused]] u8string& buffer, [[maybe_unused]] size_t maxLength) override
        {
            return nullptr;
        }
        void StopTextInput() override
        {
        }

        // In-game UI
        IWindowManager* GetWindowManager() override
        {
            return _windowManager.get();
        }

        // Clipboard
        bool SetClipboardText([[maybe_unused]] const utf8* target) override
        {
            return false;
        }

        ITitleSequencePlayer* GetTitleSequencePlayer() override
        {
            return nullptr;
        }

        // Convenience accessors for Swift interop
        uint8_t* GetPixelBuffer()
        {
            return _engine ? _engine->GetPixelBuffer() : nullptr;
        }
        uint32_t GetBufferWidth() const
        {
            return static_cast<uint32_t>(_width);
        }
        uint32_t GetBufferHeight() const
        {
            return static_cast<uint32_t>(_height);
        }
        int32_t GetBufferPitch() const
        {
            return _engine ? _engine->GetBufferPitch() : 0;
        }
        const uint32_t* GetPaletteBGRA() const
        {
            return _engine ? _engine->GetPaletteBGRA() : nullptr;
        }
    };

    std::unique_ptr<IUiContext> CreateVisionOSUiContext()
    {
        return std::make_unique<VisionOSUiContext>();
    }

    VisionOSUiContext* AsVisionOSUiContext(IUiContext* ctx)
    {
        return dynamic_cast<VisionOSUiContext*>(ctx);
    }
    } // namespace Ui
} // namespace OpenRCT2
