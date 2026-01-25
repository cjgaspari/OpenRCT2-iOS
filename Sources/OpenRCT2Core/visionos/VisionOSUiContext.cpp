/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext (stub)
 ****************************************************************************/

// Force include limits headers early for visionOS SDK compatibility
// This MUST come before any C++ stdlib headers
#include "VisionOSUiContext.h"

#include <climits>
#include <cstdint>
#include <limits.h>

// Use mach time instead of <chrono> to avoid visionOS SDK header issues
#include <mach/mach_time.h>

// Include UiContext for IUiContext base class definition
// NOTE: This must come AFTER limits headers due to visionOS SDK issues
#include <openrct2/drawing/X8DrawingEngine.h>
#include <openrct2/ui/UiContext.h>
// NOTE: WindowManager.h is NOT included to avoid sfl/static_vector.hpp dependency
// We provide a minimal stub that returns nullptr for GetWindowManager()

using namespace OpenRCT2::Drawing;

namespace OpenRCT2
{
    namespace Ui
    {
        class VisionOSUiContext final : public IUiContext
        {
        private:
            int32_t _width{ 1280 };
            int32_t _height{ 720 };
            std::unique_ptr<X8DrawingEngine> _engine;
            uint64_t _lastTick{ 0 };
            mach_timebase_info_data_t _timebaseInfo{ 0, 0 };

            uint64_t GetElapsedMilliseconds(uint64_t start, uint64_t end)
            {
                if (_timebaseInfo.denom == 0)
                {
                    mach_timebase_info(&_timebaseInfo);
                }
                uint64_t elapsed = end - start;
                // Convert to nanoseconds then to milliseconds
                return (elapsed * _timebaseInfo.numer / _timebaseInfo.denom) / 1000000;
            }

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
                dc->FillRect(*rt, PaletteIndex::pi14, 50, 50, _width - 50, _height - 50, false);
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
                // Simple ~40 Hz tick pacing for game loop stubs using mach time
                uint64_t now = mach_absolute_time();
                if (_lastTick == 0)
                {
                    _lastTick = now;
                }
                uint64_t elapsed = GetElapsedMilliseconds(_lastTick, now);
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
                // TODO: Implement window manager for visionOS when needed
                return nullptr;
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

            bool SetScreenSize(int32_t width, int32_t height)
            {
                if (width <= 0 || height <= 0)
                    return false;

                _width = width;
                _height = height;

                // Resize drawing engine if it exists
                if (_engine)
                {
                    _engine->Resize(static_cast<uint32_t>(width), static_cast<uint32_t>(height));
                }

                return true;
            }
        };

        IUiContext* CreateVisionOSUiContext()
        {
            return new VisionOSUiContext();
        }

        VisionOSUiContext* AsVisionOSUiContext(IUiContext* ctx)
        {
            return dynamic_cast<VisionOSUiContext*>(ctx);
        }
    } // namespace Ui
} // namespace OpenRCT2

// ============================================================================
// C Shim Implementation (extern "C" functions for Swift interop)
// ============================================================================

#include "../include/OpenRCT2Shim.h"

using namespace OpenRCT2::Ui;
using namespace OpenRCT2::Drawing;

// Global context and rendering state
static std::unique_ptr<IUiContext> g_uiContext;
static RenderTarget g_dummyRT = {};
static bool g_initialized = false;

bool openrct2_init(const char* configPath)
{
    (void)configPath; // Unused for now

    if (g_initialized)
        return true;

    try
    {
        // Create visionOS-specific UI context
        g_uiContext.reset(CreateVisionOSUiContext());

        if (!g_uiContext)
        {
            return false;
        }

        g_initialized = true;
        return true;
    }
    catch (...)
    {
        return false;
    }
}

void openrct2_shutdown(void)
{
    g_uiContext.reset();
    g_initialized = false;
}

void openrct2_tick(void)
{
    if (!g_initialized || !g_uiContext)
        return;

    // Process game state updates
    g_uiContext->ProcessMessages();

    // Render the current frame
    g_uiContext->Draw(g_dummyRT);
}

const uint8_t* openrct2_get_frame_buffer(void)
{
    if (!g_initialized || !g_uiContext)
        return nullptr;

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return nullptr;

    return visionosCtx->GetPixelBuffer();
}

const uint8_t* openrct2_get_palette(void)
{
    if (!g_initialized || !g_uiContext)
        return nullptr;

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return nullptr;

    // Return palette as uint8_t pointer; caller knows it's BGRA uint32_t array
    return reinterpret_cast<const uint8_t*>(visionosCtx->GetPaletteBGRA());
}

int32_t openrct2_get_pitch(void)
{
    if (!g_initialized || !g_uiContext)
        return 1280; // Default width

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return 1280;

    return visionosCtx->GetBufferPitch();
}

bool openrct2_set_screen_size(int32_t width, int32_t height)
{
    if (!g_initialized || !g_uiContext)
        return false;

    if (width <= 0 || height <= 0)
        return false;

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return false;

    return visionosCtx->SetScreenSize(width, height);
}

uint32_t openrct2_get_frame_width(void)
{
    if (!g_initialized || !g_uiContext)
        return ORCT2_SCREEN_WIDTH;

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return ORCT2_SCREEN_WIDTH;

    return visionosCtx->GetBufferWidth();
}

uint32_t openrct2_get_frame_height(void)
{
    if (!g_initialized || !g_uiContext)
        return ORCT2_SCREEN_HEIGHT;

    auto* visionosCtx = AsVisionOSUiContext(g_uiContext.get());
    if (!visionosCtx)
        return ORCT2_SCREEN_HEIGHT;

    return visionosCtx->GetBufferHeight();
}
