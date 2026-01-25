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

// os_log for reliable visionOS console logging
#include <os/log.h>

// Define a static log handle for OpenRCT2
static os_log_t g_openrct2Log = nullptr;
static inline os_log_t getOpenRCT2Log()
{
    if (!g_openrct2Log)
    {
        g_openrct2Log = os_log_create("io.openrct2.OpenRCT2", "VisionOSUiContext");
    }
    return g_openrct2Log;
}

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
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/PlatformEnvironment.h>
    #include <openrct2/audio/AudioContext.h>
    #include <openrct2/drawing/IDrawingEngine.h>
    #include <openrct2/paint/Painter.h>
    #include <openrct2/scenes/Scene.h>
    #include <openrct2/ui/WindowManager.h>
#endif

using namespace OpenRCT2::Drawing;

// Forward declarations - we'll provide our own implementation using Swift-provided paths
namespace OpenRCT2
{
    // These will be defined later in this file
    std::unique_ptr<IPlatformEnvironment> CreateVisionOSPlatformEnvironmentWithPaths(
        const std::string& bundlePath, const std::string& userPath, const std::string& cachePath);
} // namespace OpenRCT2

// ============================================================================
// VisionOS Path Helpers - paths are provided by Swift via openrct2_set_paths()
// ============================================================================

// The Objective-C path discovery code has been replaced with Swift-provided paths
// because this file is compiled as C++ (not Objective-C++) by Xcode.

static std::string CombinePath(const std::string& a, const std::string& b)
{
    if (a.empty())
        return b;
    if (b.empty())
        return a;
    if (a.back() == '/' || a.back() == '\\')
        return a + b;
    return a + "/" + b;
}

// Global path variables set by openrct2_set_paths() from Swift
static std::string g_bundlePath;
static std::string g_userPath;
static std::string g_cachePath;

// Forward declarations for accessor functions
const std::string& GetGlobalBundlePath();
const std::string& GetGlobalUserPath();
const std::string& GetGlobalCachePath();

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
             * Initialize asset paths using the global paths set from Swift.
             */
            void InitializeAssetPaths()
            {
                _bundlePath = GetGlobalBundlePath();
                _documentsPath = GetGlobalUserPath();
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
static std::string g_lastError;

#ifdef OPENRCT2_FULL_CONTEXT
static std::unique_ptr<IContext> g_context;
#endif

/**
 * Set paths from Swift before calling openrct2_init().
 * This is necessary because the C++ library built with CMake
 * cannot access NSBundle/Foundation APIs directly.
 */
void openrct2_set_paths(const char* bundlePath, const char* userPath, const char* cachePath)
{
    if (bundlePath)
        g_bundlePath = bundlePath;
    if (userPath)
        g_userPath = userPath;
    if (cachePath)
        g_cachePath = cachePath;

    printf("[OpenRCT2] Paths set from Swift:\n");
    printf("  bundlePath: %s\n", g_bundlePath.c_str());
    printf("  userPath: %s\n", g_userPath.c_str());
    printf("  cachePath: %s\n", g_cachePath.c_str());
}

// Accessor functions for VisionOSPlatformEnvironment
const std::string& GetGlobalBundlePath()
{
    return g_bundlePath;
}
const std::string& GetGlobalUserPath()
{
    return g_userPath;
}
const std::string& GetGlobalCachePath()
{
    return g_cachePath;
}

#ifdef OPENRCT2_FULL_CONTEXT
// ============================================================================
// VisionOS Platform Environment Implementation (uses Swift-provided paths)
// ============================================================================

namespace
{
    // Directory names for RCT2 data layout
    static constexpr const char* kDirectoryNamesRCT2[] = {
        "Data",        // DATA
        "Landscapes",  // LANDSCAPE
        nullptr,       // LANGUAGE
        nullptr,       // LOG_CHAT
        nullptr,       // LOG_SERVER
        nullptr,       // NETWORK_KEY
        "ObjData",     // OBJECT
        nullptr,       // PLUGIN
        "Saved Games", // SAVE
        "Scenarios",   // SCENARIO
        nullptr,       // SCREENSHOT
        nullptr,       // SEQUENCE
        nullptr,       // SHADER
        nullptr,       // THEME
        "Tracks",      // TRACK
    };

    // Directory names for OpenRCT2 user data
    static constexpr const char* kDirectoryNamesOpenRCT2[] = {
        "data",             // DATA
        "landscape",        // LANDSCAPE
        "language",         // LANGUAGE
        "chatlogs",         // LOG_CHAT
        "serverlogs",       // LOG_SERVER
        "keys",             // NETWORK_KEY
        "object",           // OBJECT
        "plugin",           // PLUGIN
        "save",             // SAVE
        "scenario",         // SCENARIO
        "screenshot",       // SCREENSHOT
        "sequence",         // SEQUENCE
        "shaders",          // SHADER
        "themes",           // THEME
        "track",            // TRACK
        "heightmap",        // HEIGHTMAP
        "replay",           // REPLAY
        "desyncs",          // DESYNCS
        "crash",            // CRASH
        "assetpack",        // ASSET_PACK
        "scenario_patches", // SCENARIO_PATCHES
    };

    // File names for various OpenRCT2 files
    static constexpr const char* kFileNames[] = {
        "config.ini",    "hotkeys.dat",       "shortcuts.json",  "objects.idx",    "tracks.idx", "scenarios.idx",
        "groups.json",   "servers.cfg",       "users.json",      "highscores.dat", "scores.dat", "Saved Games/scores.dat",
        "changelog.txt", "plugin.store.json", "contributors.md",
    };
} // namespace

namespace OpenRCT2
{
    class VisionOSPlatformEnvironmentImpl final : public IPlatformEnvironment
    {
    private:
        u8string _basePath[static_cast<size_t>(DirBase::documentation) + 1];

    public:
        VisionOSPlatformEnvironmentImpl(
            const std::string& bundlePath, const std::string& userPath, const std::string& cachePath)
        {
            // OpenRCT2 data (g2.dat, language, objects, etc.) is in the bundle
            _basePath[static_cast<size_t>(DirBase::openrct2)] = bundlePath;

            // User data directory
            auto userDataPath = CombinePath(userPath, "OpenRCT2");
            _basePath[static_cast<size_t>(DirBase::user)] = userDataPath;

            // Config in user path
            _basePath[static_cast<size_t>(DirBase::config)] = userDataPath;

            // Cache
            _basePath[static_cast<size_t>(DirBase::cache)] = cachePath;

            // Documentation in bundle
            _basePath[static_cast<size_t>(DirBase::documentation)] = bundlePath;

            // RCT2 data: check bundle first, then user
            auto bundledRCT2 = CombinePath(bundlePath, "rct2");
            auto userRCT2 = CombinePath(userDataPath, "rct2");

            // Always use bundled RCT2 if it exists (g1.dat should be there)
            _basePath[static_cast<size_t>(DirBase::rct2)] = bundledRCT2;

            // RCT1 is optional, user-provided
            _basePath[static_cast<size_t>(DirBase::rct1)] = CombinePath(userDataPath, "rct1");

            printf("[OpenRCT2] VisionOSPlatformEnvironmentImpl initialized:\n");
            printf("  openrct2: %s\n", _basePath[static_cast<size_t>(DirBase::openrct2)].c_str());
            printf("  user: %s\n", _basePath[static_cast<size_t>(DirBase::user)].c_str());
            printf("  rct2: %s\n", _basePath[static_cast<size_t>(DirBase::rct2)].c_str());
            printf("  config: %s\n", _basePath[static_cast<size_t>(DirBase::config)].c_str());
            printf("  cache: %s\n", _basePath[static_cast<size_t>(DirBase::cache)].c_str());
        }

        u8string GetDirectoryPath(DirBase base) const override
        {
            auto index = static_cast<size_t>(base);
            if (index < std::size(_basePath))
            {
                return _basePath[index];
            }
            return u8string();
        }

        u8string GetDirectoryPath(DirBase base, DirId did) const override
        {
            auto basePath = GetDirectoryPath(base);
            if (basePath.empty())
            {
                return u8string();
            }

            const char* directoryName = nullptr;
            auto didIndex = static_cast<size_t>(did);

            switch (base)
            {
                case DirBase::rct1:
                case DirBase::rct2:
                    if (didIndex < std::size(kDirectoryNamesRCT2))
                    {
                        directoryName = kDirectoryNamesRCT2[didIndex];
                    }
                    break;

                case DirBase::openrct2:
                    // visionOS bundle layout: files like g2.dat, fonts.dat are in root
                    // of visionos-resources, not in a data/ subfolder.
                    if (did == DirId::data)
                    {
                        // g2.dat, fonts.dat etc are directly in visionos-resources root
                        return basePath;
                    }
                    if (didIndex < std::size(kDirectoryNamesOpenRCT2))
                    {
                        directoryName = kDirectoryNamesOpenRCT2[didIndex];
                    }
                    break;

                default:
                    if (didIndex < std::size(kDirectoryNamesOpenRCT2))
                    {
                        directoryName = kDirectoryNamesOpenRCT2[didIndex];
                    }
                    break;
            }

            if (directoryName == nullptr)
            {
                return basePath;
            }

            return CombinePath(basePath, directoryName);
        }

        u8string GetFilePath(PathId pathid) const override
        {
            DirBase dirbase = GetDefaultBaseDirectory(pathid);
            auto basePath = GetDirectoryPath(dirbase);
            auto pathidIndex = static_cast<size_t>(pathid);

            if (pathidIndex < std::size(kFileNames))
            {
                return CombinePath(basePath, kFileNames[pathidIndex]);
            }

            return basePath;
        }

        u8string FindFile(DirBase base, DirId did, u8string_view fileName) const override
        {
            auto dataPath = GetDirectoryPath(base, did);
            return CombinePath(dataPath, std::string(fileName));
        }

        void SetBasePath(DirBase base, u8string_view path) override
        {
            auto index = static_cast<size_t>(base);
            if (index < std::size(_basePath))
            {
                _basePath[index] = u8string(path);
            }
        }

        bool IsUsingClassic() const override
        {
            return false;
        }

    private:
        static DirBase GetDefaultBaseDirectory(PathId pathid)
        {
            switch (pathid)
            {
                case PathId::config:
                case PathId::configShortcutsLegacy:
                case PathId::configShortcuts:
                    return DirBase::config;

                case PathId::cacheObjects:
                case PathId::cacheTracks:
                case PathId::cacheScenarios:
                    return DirBase::cache;

                case PathId::scoresRCT2:
                    return DirBase::rct2;

                case PathId::changelog:
                case PathId::contributors:
                    return DirBase::documentation;

                default:
                    return DirBase::user;
            }
        }
    };

    std::unique_ptr<IPlatformEnvironment> CreateVisionOSPlatformEnvironmentWithPaths(
        const std::string& bundlePath, const std::string& userPath, const std::string& cachePath)
    {
        return std::make_unique<VisionOSPlatformEnvironmentImpl>(bundlePath, userPath, cachePath);
    }
} // namespace OpenRCT2
#endif // OPENRCT2_FULL_CONTEXT

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
        printf("[OpenRCT2] openrct2_init starting...\n");

#ifdef OPENRCT2_FULL_CONTEXT
        printf("[OpenRCT2] FULL_CONTEXT mode - creating complete OpenRCT2 context\n");

        // Check if paths were set from Swift
        if (g_bundlePath.empty())
        {
            printf("[OpenRCT2] ERROR: Bundle path not set! Call openrct2_set_paths() first.\n");
            return false;
        }

        printf("[OpenRCT2] Using paths from Swift:\n");
        printf("  bundlePath: %s\n", g_bundlePath.c_str());
        printf("  userPath: %s\n", g_userPath.c_str());
        printf("  cachePath: %s\n", g_cachePath.c_str());

        // Full context mode: create complete OpenRCT2 context with paths from Swift
        auto env = CreateVisionOSPlatformEnvironmentWithPaths(g_bundlePath, g_userPath, g_cachePath);
        printf("[OpenRCT2] Created VisionOSPlatformEnvironmentWithPaths\n");

        // Log the paths
        printf("[OpenRCT2] Paths:\n");
        printf("  openrct2: %s\n", env->GetDirectoryPath(DirBase::openrct2).c_str());
        printf("  user: %s\n", env->GetDirectoryPath(DirBase::user).c_str());
        printf("  rct2: %s\n", env->GetDirectoryPath(DirBase::rct2).c_str());
        printf("  config: %s\n", env->GetDirectoryPath(DirBase::config).c_str());
        printf("  cache: %s\n", env->GetDirectoryPath(DirBase::cache).c_str());

        auto audioContext = Audio::CreateDummyAudioContext();
        printf("[OpenRCT2] Created DummyAudioContext\n");

        auto uiContext = CreateVisionOSUiContext();
        printf("[OpenRCT2] Created VisionOSUiContext\n");

        g_visionosUiContext = AsVisionOSUiContext(uiContext.get());

        g_context = CreateContext(std::move(env), std::move(audioContext), std::move(uiContext));

        if (!g_context)
        {
            g_lastError = "CreateContext returned null";
            printf("[OpenRCT2] ERROR: %s\n", g_lastError.c_str());
            return false;
        }
        printf("[OpenRCT2] CreateContext succeeded\n");

        if (g_visionosUiContext)
            g_visionosUiContext->SetContext(g_context.get());
#else
        printf("[OpenRCT2] Standalone mode - creating UI context only\n");

        // Standalone mode: just create UI context
        g_uiContext = CreateVisionOSUiContext();
        if (!g_uiContext)
        {
            g_lastError = "CreateVisionOSUiContext returned null";
            printf("[OpenRCT2] ERROR: %s\n", g_lastError.c_str());
            return false;
        }

        g_visionosUiContext = AsVisionOSUiContext(g_uiContext.get());
#endif

        g_initialized = true;
        printf("[OpenRCT2] openrct2_init completed successfully\n");
        return true;
    }
    catch (const std::exception& ex)
    {
        g_lastError = std::string("Exception in openrct2_init: ") + ex.what();
        printf("[OpenRCT2] %s\n", g_lastError.c_str());
        return false;
    }
    catch (...)
    {
        g_lastError = "Unknown exception in openrct2_init";
        printf("[OpenRCT2] %s\n", g_lastError.c_str());
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
    // Use os_log for reliable visionOS logging (appears in Console.app)
    os_log_info(getOpenRCT2Log(), "openrct2_init_full starting...");
    fprintf(stderr, "[OpenRCT2] openrct2_init_full starting...\n");
    fflush(stderr);
    printf("[OpenRCT2] openrct2_init_full starting...\n");

    if (!g_initialized)
    {
        g_lastError = "openrct2_init not called";
        printf("[OpenRCT2] ERROR: %s\n", g_lastError.c_str());
        return false;
    }

    if (g_contextInitialized)
    {
        printf("[OpenRCT2] Already fully initialized\n");
        return true;
    }

#ifdef OPENRCT2_FULL_CONTEXT
    os_log_info(getOpenRCT2Log(), "OPENRCT2_FULL_CONTEXT is defined - using full context initialization");
    fprintf(stderr, "[OpenRCT2] OPENRCT2_FULL_CONTEXT is defined\n");
    fflush(stderr);
    try
    {
        if (!g_context)
        {
            g_lastError = "g_context is null";
            printf("[OpenRCT2] ERROR: %s\n", g_lastError.c_str());
            return false;
        }

        // Set the RCT2 data path to our bundled data to skip the directory browser
        auto rct2Path = CombinePath(g_bundlePath, "rct2");
        printf("[OpenRCT2] Setting gCustomRCT2DataPath to: %s\n", rct2Path.c_str());
        gCustomRCT2DataPath = rct2Path;

        printf("[OpenRCT2] Calling g_context->Initialise()...\n");
        os_log_info(getOpenRCT2Log(), "Calling g_context->Initialise()...");
        fprintf(stderr, "[OpenRCT2] Calling g_context->Initialise()...\n");
        fflush(stderr);
        if (!g_context->Initialise())
        {
            g_lastError = "Context::Initialise() returned false";
            printf("[OpenRCT2] ERROR: %s\n", g_lastError.c_str());
            return false;
        }
        printf("[OpenRCT2] Context::Initialise() succeeded\n");

        printf("[OpenRCT2] Calling InitialiseDrawingEngine()...\n");
        g_context->InitialiseDrawingEngine();
        printf("[OpenRCT2] InitialiseDrawingEngine() succeeded\n");

        auto* titleScene = g_context->GetTitleScene();
        if (titleScene)
        {
            printf("[OpenRCT2] Setting title scene as active\n");
            g_context->SetActiveScene(titleScene);
        }
        else
        {
            printf("[OpenRCT2] Warning: GetTitleScene() returned null\n");
        }

        g_contextInitialized = true;
        printf("[OpenRCT2] openrct2_init_full completed successfully\n");
        return true;
    }
    catch (const std::exception& ex)
    {
        g_lastError = std::string("Exception in openrct2_init_full: ") + ex.what();
        printf("[OpenRCT2] %s\n", g_lastError.c_str());
        return false;
    }
    catch (...)
    {
        g_lastError = "Unknown exception in openrct2_init_full";
        printf("[OpenRCT2] %s\n", g_lastError.c_str());
        return false;
    }
#else
    // Standalone mode: always "fully initialized"
    g_contextInitialized = true;
    os_log_info(getOpenRCT2Log(), "Standalone mode - OPENRCT2_FULL_CONTEXT NOT defined");
    fprintf(stderr, "[OpenRCT2] Standalone mode - OPENRCT2_FULL_CONTEXT NOT defined\n");
    fflush(stderr);
    printf("[OpenRCT2] Standalone mode - marking as fully initialized\n");
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
 *
 * If full context is initialized, runs the real game.
 * Otherwise, falls back to standalone test pattern mode.
 */
void openrct2_tick(void)
{
    if (!g_initialized)
        return;

#ifdef OPENRCT2_FULL_CONTEXT
    // If full context is ready, use it
    if (g_context && g_contextInitialized)
    {
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
        return;
    }
#endif

    // Fallback: standalone test pattern mode
    if (g_visionosUiContext)
    {
        g_visionosUiContext->ProcessMessages();
        g_visionosUiContext->Draw(g_dummyRT);
    }
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
    return g_lastError.empty() ? nullptr : g_lastError.c_str();
}
