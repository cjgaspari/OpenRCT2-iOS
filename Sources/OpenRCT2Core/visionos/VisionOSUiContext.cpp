/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext
 *
 * VOS-035: Full GameContext Initialization
 * - Creates full OpenRCT2 Context with proper platform environment
 * - Integrates with real Painter and drawing engine
 * - Supports Swift-managed game loop (40Hz ticks)
 * - Exposes frame buffer for Metal rendering
 *
 * VOS-036: Proper drawing engine with game palette
 * VOS-037: Asset path discovery for visionOS bundle
 *
 * Build Modes:
 * - OPENRCT2_FULL_CONTEXT: Full library linked, real game rendering
 * - Otherwise: Standalone mode with test pattern (current SPM build)
 ****************************************************************************/

// Force include limits headers early for visionOS SDK compatibility
// This MUST come before any C++ stdlib headers
#include "VisionOSUiContext.h"

#include <climits>
#include <cmath>
#include <cstdint>
#include <limits.h>

// Use mach time instead of <chrono> to avoid visionOS SDK header issues
#include <mach/mach_time.h>

// Objective-C headers for bundle path discovery
#ifdef __OBJC__
    #import <Foundation/Foundation.h>
#endif

// OpenRCT2 headers for drawing
#include <openrct2/drawing/X8DrawingEngine.h>
#include <openrct2/ui/UiContext.h>

// Full context headers - only when OPENRCT2_FULL_CONTEXT is defined
#ifdef OPENRCT2_FULL_CONTEXT
    #include <openrct2/Context.h>
    #include <openrct2/PlatformEnvironment.h>
    #include <openrct2/audio/AudioContext.h>
    #include <openrct2/drawing/IDrawingEngine.h>
    #include <openrct2/paint/Painter.h>
    #include <openrct2/ui/WindowManager.h>
#endif

using namespace OpenRCT2::Drawing;

// Forward declaration from VisionOSPlatformEnvironment.cpp
namespace OpenRCT2
{
    std::unique_ptr<IPlatformEnvironment> CreateVisionOSPlatformEnvironment();
}

// ============================================================================
// VisionOS Path Helpers (Objective-C++)
// ============================================================================

#ifdef __OBJC__
/**
 * Get the app bundle's resource path.
 */
static std::string GetVisionOSBundlePath()
{
    @autoreleasepool
    {
        NSBundle* bundle = [NSBundle mainBundle];
        if (bundle && bundle.bundleIdentifier)
        {
            auto resources = bundle.resourcePath.UTF8String;
            if (resources)
            {
                return std::string(resources);
            }
        }
        return std::string();
    }
}

/**
 * Get the Documents directory for user data.
 */
static std::string GetVisionOSDocumentsPath()
{
    @autoreleasepool
    {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (paths.count > 0)
        {
            return std::string([paths.firstObject UTF8String]);
        }
        return std::string();
    }
}

/**
 * Check if a file exists.
 */
static bool FileExistsAt(const std::string& path)
{
    @autoreleasepool
    {
        return [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:path.c_str()]];
    }
}
#else
static std::string GetVisionOSBundlePath()
{
    return ".";
}
static std::string GetVisionOSDocumentsPath()
{
    return ".";
}
static bool FileExistsAt(const std::string&)
{
    return false;
}
#endif

namespace OpenRCT2
{
    namespace Ui
    {
        /**
         * VisionOS implementation of IUiContext.
         *
         * VOS-035: Full GameContext Integration
         * - Works with the real OpenRCT2 Context and Painter (when OPENRCT2_FULL_CONTEXT)
         * - Falls back to standalone test pattern in standalone mode
         * - Frame buffer is accessible for Metal rendering
         */
        class VisionOSUiContext final : public IUiContext
        {
        private:
            int32_t _width{ 1280 };
            int32_t _height{ 720 };

            // Standalone mode: own drawing engine
            std::unique_ptr<X8DrawingEngine> _standaloneEngine;
            uint32_t _tickCount{ 0 };

#ifdef OPENRCT2_FULL_CONTEXT
            // Full context mode: references to context-owned objects
            IContext* _context{ nullptr };
            std::unique_ptr<IWindowManager> _windowManager;
#endif

            // Timing for game loop
            uint64_t _lastTick{ 0 };
            mach_timebase_info_data_t _timebaseInfo{ 0, 0 };

            // Asset paths
            std::string _bundlePath;
            std::string _documentsPath;

            uint64_t GetElapsedMilliseconds(uint64_t start, uint64_t end)
            {
                if (_timebaseInfo.denom == 0)
                {
                    mach_timebase_info(&_timebaseInfo);
                }
                uint64_t elapsed = end - start;
                return (elapsed * _timebaseInfo.numer / _timebaseInfo.denom) / 1000000;
            }

            /**
             * Initialize asset paths.
             */
            void InitializeAssetPaths()
            {
                _bundlePath = GetVisionOSBundlePath();
                _documentsPath = GetVisionOSDocumentsPath();
            }

            /**
             * Setup a game-like palette for test pattern rendering.
             */
            void SetupGamePalette()
            {
                if (!_standaloneEngine)
                    return;

                GamePalette pal{};

                // Index 0 is transparent/black
                pal[0] = { 0, 0, 0, 0 };

                // Grays for UI
                for (size_t i = 1; i <= 9; ++i)
                {
                    uint8_t gray = static_cast<uint8_t>(28 * i);
                    pal[i] = { gray, gray, gray, 255 };
                }

                // Background/UI colors
                pal[10] = { 20, 20, 40, 255 };
                pal[11] = { 30, 30, 60, 255 };
                pal[12] = { 40, 40, 80, 255 };
                pal[13] = { 50, 50, 100, 255 };
                pal[14] = { 60, 90, 130, 255 };
                pal[15] = { 80, 120, 160, 255 };

                // Warm terrain colors
                for (size_t i = 16; i <= 31; ++i)
                {
                    uint8_t r = static_cast<uint8_t>(100 + (i - 16) * 9);
                    uint8_t g = static_cast<uint8_t>(80 + (i - 16) * 6);
                    uint8_t b = static_cast<uint8_t>(40 + (i - 16) * 4);
                    pal[i] = { b, g, r, 255 };
                }

                // Green foliage colors
                for (size_t i = 32; i <= 47; ++i)
                {
                    uint8_t r = static_cast<uint8_t>(20 + (i - 32) * 4);
                    uint8_t g = static_cast<uint8_t>(80 + (i - 32) * 8);
                    uint8_t b = static_cast<uint8_t>(20 + (i - 32) * 3);
                    pal[i] = { b, g, r, 255 };
                }

                // Water blues
                for (size_t i = 48; i <= 63; ++i)
                {
                    uint8_t r = static_cast<uint8_t>(10 + (i - 48) * 4);
                    uint8_t g = static_cast<uint8_t>(60 + (i - 48) * 8);
                    uint8_t b = static_cast<uint8_t>(120 + (i - 48) * 6);
                    pal[i] = { b, g, r, 255 };
                }

                // Red warning colors
                for (size_t i = 64; i <= 79; ++i)
                {
                    uint8_t r = static_cast<uint8_t>(150 + (i - 64) * 6);
                    uint8_t g = static_cast<uint8_t>(30 + (i - 64) * 4);
                    uint8_t b = static_cast<uint8_t>(30 + (i - 64) * 2);
                    pal[i] = { b, g, r, 255 };
                }

                // Gradient for remaining indices
                for (size_t i = 80; i < 256; ++i)
                {
                    uint8_t hue = static_cast<uint8_t>((i - 80) * 255 / 176);
                    uint8_t r, g, b;
                    if (hue < 85)
                    {
                        r = 255 - hue * 3;
                        g = hue * 3;
                        b = 0;
                    }
                    else if (hue < 170)
                    {
                        uint8_t h = hue - 85;
                        r = 0;
                        g = 255 - h * 3;
                        b = h * 3;
                    }
                    else
                    {
                        uint8_t h = hue - 170;
                        r = h * 3;
                        g = 0;
                        b = 255 - h * 3;
                    }
                    pal[i] = { b, g, r, 255 };
                }

                _standaloneEngine->SetPalette(pal);
            }

            /**
             * Draw test pattern for standalone mode.
             */
            void DrawTestPattern()
            {
                if (!_standaloneEngine)
                    return;

                auto* dc = static_cast<X8DrawingContext*>(_standaloneEngine->GetDrawingContext());
                auto* rt = _standaloneEngine->getRT();
                if (!dc || !rt)
                    return;

                // Clear to dark background
                dc->Clear(*rt, PaletteIndex::pi10);

                // Color palette bars
                int barHeight = 20;
                int barWidth = _width / 16;
                for (int i = 0; i < 16; ++i)
                {
                    PaletteIndex color = static_cast<PaletteIndex>(16 + i);
                    dc->FillRect(*rt, color, i * barWidth, 0, (i + 1) * barWidth, barHeight, false);
                }
                for (int i = 0; i < 16; ++i)
                {
                    PaletteIndex color = static_cast<PaletteIndex>(32 + i);
                    dc->FillRect(*rt, color, i * barWidth, barHeight, (i + 1) * barWidth, barHeight * 2, false);
                }
                for (int i = 0; i < 16; ++i)
                {
                    PaletteIndex color = static_cast<PaletteIndex>(48 + i);
                    dc->FillRect(*rt, color, i * barWidth, barHeight * 2, (i + 1) * barWidth, barHeight * 3, false);
                }

                // Animated spinner
                int centerX = _width / 2;
                int centerY = _height / 2;
                int spinnerSize = 100;
                int angle = (_tickCount * 3) % 360;

                for (int seg = 0; seg < 8; ++seg)
                {
                    int segAngle = (angle + seg * 45) % 360;
                    int intensity = (seg + (_tickCount / 4)) % 8;
                    PaletteIndex color = static_cast<PaletteIndex>(64 + intensity * 2);

                    float rad = segAngle * 3.14159f / 180.0f;
                    int x1 = centerX + static_cast<int>(spinnerSize * 0.4f * std::cos(rad));
                    int y1 = centerY + static_cast<int>(spinnerSize * 0.4f * std::sin(rad));
                    int x2 = centerX + static_cast<int>(spinnerSize * std::cos(rad));
                    int y2 = centerY + static_cast<int>(spinnerSize * std::sin(rad));

                    int dx = (x2 - x1) / 10;
                    int dy = (y2 - y1) / 10;
                    for (int step = 0; step < 10; ++step)
                    {
                        int px = x1 + dx * step;
                        int py = y1 + dy * step;
                        dc->FillRect(*rt, color, px - 2, py - 2, px + 2, py + 2, false);
                    }
                }

                // Info box
                int boxLeft = 50;
                int boxTop = barHeight * 3 + 50;
                int boxRight = _width - 50;
                int boxBottom = boxTop + 120;

                dc->FillRect(*rt, PaletteIndex::pi12, boxLeft, boxTop, boxRight, boxBottom, false);
                dc->FillRect(*rt, PaletteIndex::pi11, boxLeft + 2, boxTop + 2, boxRight - 2, boxBottom - 2, false);
                dc->FillRect(*rt, PaletteIndex::pi14, boxLeft, boxTop, boxRight, boxTop + 2, false);
                dc->FillRect(*rt, PaletteIndex::pi14, boxLeft, boxBottom - 2, boxRight, boxBottom, false);
                dc->FillRect(*rt, PaletteIndex::pi14, boxLeft, boxTop, boxLeft + 2, boxBottom, false);
                dc->FillRect(*rt, PaletteIndex::pi14, boxRight - 2, boxTop, boxRight, boxBottom, false);

                // Progress bar
                int progressWidth = (_tickCount * 3) % (_width - 100);
                dc->FillRect(*rt, PaletteIndex::pi13, 50, _height - 30, 50 + progressWidth, _height - 20, false);
            }

        public:
            VisionOSUiContext()
            {
                InitializeAssetPaths();
#ifdef OPENRCT2_FULL_CONTEXT
                _windowManager = CreateDummyWindowManager();
#endif
            }

#ifdef OPENRCT2_FULL_CONTEXT
            void SetContext(IContext* context)
            {
                _context = context;
            }

            IContext* GetContextRef() const
            {
                return _context;
            }
#endif

            void InitialiseScriptExtensions() override
            {
            }

            void Tick() override
            {
                _tickCount++;
            }

            void Draw(RenderTarget& /*rt*/) override
            {
                // In standalone mode, draw test pattern
                if (!_standaloneEngine)
                {
                    _standaloneEngine = std::make_unique<X8DrawingEngine>(*this);
                    _standaloneEngine->Initialise();
                    _standaloneEngine->Resize(static_cast<uint32_t>(_width), static_cast<uint32_t>(_height));
                    SetupGamePalette();
                }

                _standaloneEngine->BeginDraw();
                DrawTestPattern();
                _standaloneEngine->EndDraw();
            }

            // Window management
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
                static std::vector<Resolution> res = { { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } };
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

            // Dialogs
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
            int32_t ShowMenuDialog(const std::vector<std::string>& options, const std::string&, const std::string&) override
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

            // Drawing engine factory
            class X8DrawingEngineFactory final : public IDrawingEngineFactory
            {
                std::unique_ptr<IDrawingEngine> Create([[maybe_unused]] DrawingEngine type, IUiContext& uiContext) override
                {
                    return std::make_unique<X8DrawingEngine>(uiContext);
                }
            };

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

            // Window Manager
            IWindowManager* GetWindowManager() override
            {
#ifdef OPENRCT2_FULL_CONTEXT
                return _windowManager.get();
#else
                return nullptr;
#endif
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

            // ================================================================
            // VisionOS-specific accessors for Swift/Metal integration
            // ================================================================

            uint8_t* GetPixelBuffer()
            {
#ifdef OPENRCT2_FULL_CONTEXT
                if (_context)
                {
                    auto* engine = dynamic_cast<X8DrawingEngine*>(_context->GetDrawingEngine());
                    if (engine)
                        return engine->GetPixelBuffer();
                }
#endif
                return _standaloneEngine ? _standaloneEngine->GetPixelBuffer() : nullptr;
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
#ifdef OPENRCT2_FULL_CONTEXT
                if (_context)
                {
                    auto* engine = dynamic_cast<X8DrawingEngine*>(_context->GetDrawingEngine());
                    if (engine)
                        return engine->GetBufferPitch();
                }
#endif
                return _standaloneEngine ? _standaloneEngine->GetBufferPitch() : _width;
            }

            const uint32_t* GetPaletteBGRA() const
            {
#ifdef OPENRCT2_FULL_CONTEXT
                if (_context)
                {
                    auto* engine = dynamic_cast<X8DrawingEngine*>(_context->GetDrawingEngine());
                    if (engine)
                        return engine->GetPaletteBGRA();
                }
#endif
                return _standaloneEngine ? _standaloneEngine->GetPaletteBGRA() : nullptr;
            }

            bool SetScreenSize(int32_t width, int32_t height)
            {
                if (width <= 0 || height <= 0)
                    return false;

                _width = width;
                _height = height;

#ifdef OPENRCT2_FULL_CONTEXT
                if (_context)
                {
                    auto* engine = _context->GetDrawingEngine();
                    if (engine)
                    {
                        engine->Resize(static_cast<uint32_t>(width), static_cast<uint32_t>(height));
                        return true;
                    }
                }
#endif
                if (_standaloneEngine)
                {
                    _standaloneEngine->Resize(static_cast<uint32_t>(width), static_cast<uint32_t>(height));
                }
                return true;
            }

            const std::string& GetBundlePath() const
            {
                return _bundlePath;
            }
            const std::string& GetDocumentsPath() const
            {
                return _documentsPath;
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

// ============================================================================
// C Shim Implementation (extern "C" functions for Swift interop)
// VOS-035: Full GameContext Integration
// ============================================================================

#include "../include/OpenRCT2Shim.h"

using namespace OpenRCT2;
using namespace OpenRCT2::Ui;
using namespace OpenRCT2::Drawing;

// Global context state
static std::unique_ptr<IUiContext> g_uiContext;
static VisionOSUiContext* g_visionosUiContext = nullptr;
static bool g_initialized = false;
static bool g_contextInitialized = false;
static RenderTarget g_dummyRT = {};

#ifdef OPENRCT2_FULL_CONTEXT
static std::unique_ptr<IContext> g_context;
#endif

/**
 * VOS-035: Initialize OpenRCT2.
 *
 * In standalone mode: Creates VisionOSUiContext with test pattern rendering.
 * In full context mode: Creates full OpenRCT2 Context ready for game.
 */
bool openrct2_init(const char* configPath)
{
    (void)configPath;

    if (g_initialized)
        return true;

    try
    {
#ifdef OPENRCT2_FULL_CONTEXT
        // Full context mode: create complete OpenRCT2 context
        auto env = CreateVisionOSPlatformEnvironment();
        auto audioContext = Audio::CreateDummyAudioContext();
        auto uiContext = CreateVisionOSUiContext();
        g_visionosUiContext = AsVisionOSUiContext(uiContext.get());

        g_context = CreateContext(std::move(env), std::move(audioContext), std::move(uiContext));

        if (!g_context)
            return false;

        if (g_visionosUiContext)
            g_visionosUiContext->SetContext(g_context.get());
#else
        // Standalone mode: just create UI context
        g_uiContext = CreateVisionOSUiContext();
        if (!g_uiContext)
            return false;

        g_visionosUiContext = AsVisionOSUiContext(g_uiContext.get());
#endif

        g_initialized = true;
        return true;
    }
    catch (...)
    {
        return false;
    }
}

/**
 * VOS-035: Complete OpenRCT2 initialization (full context mode only).
 *
 * Loads g1.dat, g2.dat, initializes repositories, drawing engine.
 * In standalone mode, this is a no-op that returns true.
 */
bool openrct2_init_full(void)
{
    if (!g_initialized)
        return false;

    if (g_contextInitialized)
        return true;

#ifdef OPENRCT2_FULL_CONTEXT
    try
    {
        if (!g_context)
            return false;

        if (!g_context->Initialise())
            return false;

        g_context->InitialiseDrawingEngine();

        auto* titleScene = g_context->GetTitleScene();
        if (titleScene)
            g_context->SetActiveScene(titleScene);

        g_contextInitialized = true;
        return true;
    }
    catch (...)
    {
        return false;
    }
#else
    // Standalone mode: always "fully initialized"
    g_contextInitialized = true;
    return true;
#endif
}

void openrct2_shutdown(void)
{
#ifdef OPENRCT2_FULL_CONTEXT
    g_context.reset();
#else
    g_uiContext.reset();
#endif
    g_visionosUiContext = nullptr;
    g_initialized = false;
    g_contextInitialized = false;
}

/**
 * VOS-035: Game tick - advances game state and renders frame.
 */
void openrct2_tick(void)
{
    if (!g_initialized)
        return;

#ifdef OPENRCT2_FULL_CONTEXT
    if (!g_context || !g_contextInitialized)
        return;

    g_context->GetUiContext().ProcessMessages();

    auto* activeScene = g_context->GetActiveScene();
    if (activeScene)
        activeScene->Tick();

    auto* drawingEngine = g_context->GetDrawingEngine();
    auto* painter = g_context->GetPainter();

    if (drawingEngine && painter)
    {
        drawingEngine->BeginDraw();
        painter->Paint(*drawingEngine);
        drawingEngine->EndDraw();
    }
#else
    if (!g_uiContext)
        return;

    g_uiContext->ProcessMessages();
    g_uiContext->Draw(g_dummyRT);
#endif
}

const uint8_t* openrct2_get_frame_buffer(void)
{
    if (!g_initialized || !g_visionosUiContext)
        return nullptr;

    return g_visionosUiContext->GetPixelBuffer();
}

const uint8_t* openrct2_get_palette(void)
{
    if (!g_initialized || !g_visionosUiContext)
        return nullptr;

    return reinterpret_cast<const uint8_t*>(g_visionosUiContext->GetPaletteBGRA());
}

int32_t openrct2_get_pitch(void)
{
    if (!g_initialized || !g_visionosUiContext)
        return ORCT2_SCREEN_WIDTH;

    return g_visionosUiContext->GetBufferPitch();
}

bool openrct2_set_screen_size(int32_t width, int32_t height)
{
    if (!g_initialized || !g_visionosUiContext)
        return false;

    if (width <= 0 || height <= 0)
        return false;

    return g_visionosUiContext->SetScreenSize(width, height);
}

uint32_t openrct2_get_frame_width(void)
{
    if (!g_initialized || !g_visionosUiContext)
        return ORCT2_SCREEN_WIDTH;

    return g_visionosUiContext->GetBufferWidth();
}

uint32_t openrct2_get_frame_height(void)
{
    if (!g_initialized || !g_visionosUiContext)
        return ORCT2_SCREEN_HEIGHT;

    return g_visionosUiContext->GetBufferHeight();
}

bool openrct2_is_fully_initialized(void)
{
    return g_contextInitialized;
}

const char* openrct2_get_init_error(void)
{
    return nullptr;
}
