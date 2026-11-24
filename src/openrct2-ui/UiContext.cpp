/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "UiContext.h"
#include "CursorRepository.h"
#include "SDLException.h"
#include "TextComposition.h"
#include "WindowManager.h"
#include "drawing/engines/DrawingEngineFactory.hpp"
#include "input/ShortcutIds.h"
#include "input/ShortcutManager.h"
#include "interface/InGameConsole.h"
#include "interface/Theme.h"
#include "interface/ViewportInteraction.h"
#include "scripting/UiExtensions.h"
#include "title/TitleSequencePlayer.h"

#include <SDL.h>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <memory>
#include <openrct2-ui/input/InputManager.h>
#include <openrct2-ui/input/MouseInput.h>
#include <openrct2-ui/interface/Window.h>
#include <openrct2/Context.h>
#include <openrct2/Diagnostic.h>
#include <openrct2/Input.h>
#include <openrct2/Version.h>
#include <openrct2/audio/AudioContext.h>
#include <openrct2/audio/AudioMixer.h>
#include <openrct2/config/Config.h>
#include <openrct2/core/String.hpp>
#include <openrct2/drawing/Drawing.h>
#include <openrct2/drawing/IDrawingEngine.h>
#include <openrct2/drawing/NewDrawing.h>
#include <openrct2/drawing/RenderTarget.h>
#include <openrct2/interface/Chat.h>
#include <openrct2/interface/ScreenCoords.hpp>
#include <openrct2/interface/Viewport.h>
#include <openrct2/scenes/title/TitleSequencePlayer.h>
#include <openrct2/ui/UiContext.h>
#include <openrct2/ui/WindowManager.h>
#include <vector>

#if defined(__APPLE__) && defined(__MACH__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IOS
        #include "IosSafeArea.h"
    #endif
#endif

#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

using namespace OpenRCT2;
using namespace OpenRCT2::Drawing;
using namespace OpenRCT2::Ui;

#ifdef __MACOSX__
    // macOS uses COMMAND rather than CTRL for many keyboard shortcuts
    #define KB_PRIMARY_MODIFIER KMOD_GUI
#else
    #define KB_PRIMARY_MODIFIER KMOD_CTRL
#endif

class UiContext final : public IUiContext
{
private:
    constexpr static uint32_t kTouchDoubleTimeout = 390;

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
    constexpr static int32_t kTouchDragThreshold = 8;
    constexpr static int32_t kTouchOneFingerPanThreshold = 10;
    constexpr static int32_t kTouchPanStartThreshold = 3;
    constexpr static int32_t kTouchConstructionPanStartThreshold = 12;
    constexpr static int32_t kTouchRemovalPanStartThreshold = 10;
    constexpr static int32_t kTouchRemovalDragThreshold = 6;
    constexpr static float kTouchPinchThreshold = 24.0f;
    constexpr static float kTouchPinchSpanRatio = 0.12f;
    constexpr static float kTouchPinchDominance = 1.5f;
    constexpr static float kTouchPanSensitivity = 0.5f;
    constexpr static float kTouchZoomStep = 20.0f;
    constexpr static uint32_t kTouchLongPressTimeout = 500;
    constexpr static int32_t kTouchToolTapDistance = 32;
    constexpr static int32_t kTrackpadViewportWheelStep = 4;
    constexpr static uint32_t kTouchPaintHoldTimeout = 350;
    constexpr static float kTouchRotationThreshold = 0.26179939f;
    constexpr static float kTouchRotationStep = 0.52359878f;
    constexpr static float kTouchRotationDominance = 1.5f;

    enum class TouchGestureMode
    {
        none,
        singlePending,
        singleDrag,
        singlePan,
        longPressFired,
        multiPending,
        multiPan,
        multiPinch,
        multiRotate,
        multiRemove,
        suppressed,
    };

    struct TouchPoint
    {
        SDL_FingerID id = -1;
        ScreenCoordsXY position{};
        bool active = false;
    };
#endif

    const std::unique_ptr<IPlatformUiContext> _platformUiContext;
    const std::unique_ptr<IWindowManager> _windowManager;

    CursorRepository _cursorRepository;

    SDL_Window* _window = nullptr;
    int32_t _width = 0;
    int32_t _height = 0;
    ScaleQuality _scaleQuality = ScaleQuality::nearestNeighbour;

    std::vector<Resolution> _fsResolutions;

    bool _steamOverlayActive = false;

    // Input
    InputManager _inputManager;
    ShortcutManager _shortcutManager;
    TextComposition _textComposition;
    CursorState _cursorState = {};
    uint32_t _lastKeyPressed = 0;
    const uint8_t* _keysState = nullptr;
    uint8_t _keysPressed[256] = {};
    [[maybe_unused]] uint32_t _lastGestureTimestamp = 0;
    [[maybe_unused]] float _gestureRadius = 0;

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
    TouchPoint _primaryTouch;
    TouchPoint _secondaryTouch;
    TouchGestureMode _touchGestureMode = TouchGestureMode::none;
    ScreenCoordsXY _touchGestureStart{};
    ScreenCoordsXY _touchLastCentroid{};
    float _touchPanCursorX = 0;
    float _touchPanCursorY = 0;
    float _touchGestureStartSpan = 0;
    float _touchLastSpan = 0;
    float _touchPinchAccumulator = 0;
    uint32_t _touchGestureStartTimestamp = 0;
    ScreenCoordsXY _lastTouchToolTap{};
    uint32_t _lastTouchToolTapTimestamp = 0;
    int32_t _trackpadViewportWheelAccumulator = 0;
    float _touchGestureStartAngle = 0;
    float _touchLastAngle = 0;
    float _touchRotationAccumulator = 0;
    ScreenCoordsXY _touchLastRemovePosition{};
#endif

    InGameConsole _inGameConsole;
    std::unique_ptr<ITitleSequencePlayer> _titleSequencePlayer;

    ScreenCoordsXY MapWindowPointToCanvas(float windowX, float windowY) const
    {
        const auto scale = Config::Get().general.windowScale;
        return { static_cast<int32_t>(windowX / scale), static_cast<int32_t>(windowY / scale) };
    }

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
    #include "input/UiContext.TouchGestures.iOS.inc.hpp"
#endif

public:
    InGameConsole& GetInGameConsole()
    {
        return _inGameConsole;
    }

    InputManager& GetInputManager()
    {
        return _inputManager;
    }

    ShortcutManager& GetShortcutManager()
    {
        return _shortcutManager;
    }

    explicit UiContext(IPlatformEnvironment& env)
        : _platformUiContext(CreatePlatformUiContext())
        , _windowManager(CreateWindowManager())
        , _shortcutManager(env)
    {
        LogSDLVersion();
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) < 0)
        {
            SDLException::Throw("SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK)");
        }
        _cursorRepository.LoadCursors();
        _shortcutManager.loadUserBindings();
    }

    ~UiContext() override
    {
        UiContext::CloseWindow();
        SDL_QuitSubSystem(SDL_INIT_VIDEO);
    }

    void InitialiseScriptExtensions() override
    {
#ifdef ENABLE_SCRIPTING
        auto& scriptEngine = GetContext()->GetScriptEngine();
        Scripting::UiScriptExtensions::Extend(scriptEngine);
#endif
    }

    void Tick() override
    {
        _inGameConsole.Update();

        _windowManager->UpdateMapTooltip();

        WindowDispatchUpdateAll();
        _platformUiContext->TickNativeOverlay();
    }

    void Draw(RenderTarget& rt) override
    {
        auto bgColour = ThemeGetColour(WindowClass::chat, 0);
        ChatDraw(rt, bgColour);
        _inGameConsole.Draw(rt);
    }

    // Window
    void* GetWindow() override
    {
        return _window;
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
        return _scaleQuality;
    }

    void SetFullscreenMode(FullscreenMode mode) override
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        // UIKit owns the main window geometry. Applying saved desktop window sizes here
        // produces a logical canvas whose aspect ratio differs from the Metal drawable.
        static_cast<void>(mode);
#else
    #ifndef __EMSCRIPTEN__
        static constexpr int32_t kSDLFullscreenFlags[] = {
            0,
            SDL_WINDOW_FULLSCREEN,
            SDL_WINDOW_FULLSCREEN_DESKTOP,
        };
        uint32_t windowFlags = kSDLFullscreenFlags[EnumValue(mode)];

        // HACK Changing window size when in fullscreen usually has no effect
        if (mode == FullscreenMode::fullscreen)
        {
            SDL_SetWindowFullscreen(_window, 0);

            // Set window size
            UpdateFullscreenResolutions();
            Resolution resolution = GetClosestResolution(
                Config::Get().general.fullscreenWidth, Config::Get().general.fullscreenHeight);
            SDL_SetWindowSize(_window, resolution.Width, resolution.Height);
        }
        else if (mode == FullscreenMode::windowed)
        {
            SDL_SetWindowSize(_window, Config::Get().general.windowWidth, Config::Get().general.windowHeight);
        }

        if (SDL_SetWindowFullscreen(_window, windowFlags))
        {
            LOG_FATAL("SDL_SetWindowFullscreen %s", SDL_GetError());
            exit(1);

            // TODO try another display mode rather than just exiting the game
        }
    #else
        if (mode == FullscreenMode::fullscreen)
        {
            emscripten_request_fullscreen("!canvas", false);
        }
        else if (mode == FullscreenMode::windowed)
        {
            emscripten_exit_fullscreen();
        }
    #endif // __EMSCRIPTEN__
#endif
    }

    const std::vector<Resolution>& GetFullscreenResolutions() override
    {
        UpdateFullscreenResolutions();
        return _fsResolutions;
    }

    bool HasFocus() override
    {
        uint32_t windowFlags = GetWindowFlags();
        return (windowFlags & SDL_WINDOW_INPUT_FOCUS) != 0;
    }

    void requestUserAttention() override
    {
        SDL_FlashWindow(_window, SDL_FLASH_UNTIL_FOCUSED);
    }

    bool IsMinimised() override
    {
        uint32_t windowFlags = GetWindowFlags();
        return (windowFlags & SDL_WINDOW_MINIMIZED) || (windowFlags & SDL_WINDOW_HIDDEN);
    }

    bool IsSteamOverlayActive() override
    {
        return _steamOverlayActive;
    }

    // Input
    const CursorState* GetCursorState() override
    {
        return &_cursorState;
    }

    const uint8_t* GetKeysState() override
    {
        return _keysState;
    }

    const uint8_t* GetKeysPressed() override
    {
        return _keysPressed;
    }

    CursorID GetCursor() override
    {
        return _cursorRepository.GetCurrentCursor();
    }

    void SetCursor(CursorID cursor) override
    {
        _cursorRepository.SetCurrentCursor(cursor);
    }

    void SetCursorScale(uint8_t scale) override
    {
        _cursorRepository.SetCursorScale(scale);
    }

    void SetCursorVisible(bool value) override
    {
        SDL_ShowCursor(value ? SDL_ENABLE : SDL_DISABLE);
    }

    ScreenCoordsXY GetCursorPosition() override
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        if (_touchGestureMode == TouchGestureMode::multiPan
            || _touchGestureMode == TouchGestureMode::singlePan)
        {
            return _cursorState.position;
        }
#endif
        ScreenCoordsXY cursorPosition;
        SDL_GetMouseState(&cursorPosition.x, &cursorPosition.y);
        return cursorPosition;
    }

    void SetCursorPosition(const ScreenCoordsXY& cursorPosition) override
    {
        SDL_WarpMouseInWindow(nullptr, cursorPosition.x, cursorPosition.y);
    }

    void SetCursorTrap(bool value) override
    {
        SDL_SetWindowGrab(_window, value ? SDL_TRUE : SDL_FALSE);
    }

    void SetKeysPressed(uint32_t keysym, uint8_t scancode) override
    {
        _lastKeyPressed = keysym;
        _keysPressed[scancode] = 1;
    }

    // Drawing
    std::shared_ptr<IDrawingEngineFactory> GetDrawingEngineFactory() override
    {
        return std::make_shared<DrawingEngineFactory>();
    }

    void DrawWeatherAnimation(IWeatherDrawer* weatherDrawer, RenderTarget& rt, DrawWeatherFunc drawFunc) override
    {
        int32_t left = rt.x;
        int32_t right = left + rt.width;
        int32_t top = rt.y;
        int32_t bottom = top + rt.height;

        for (auto& w : gWindowList)
        {
            DrawWeatherWindow(rt, weatherDrawer, w.get(), left, right, top, bottom, drawFunc);
        }
    }

    // Text input
    bool IsTextInputActive() override
    {
        return _textComposition.IsActive();
    }

    TextInputSession* StartTextInput(u8string& buffer, size_t maxLength) override
    {
        auto* session = _textComposition.Start(buffer, maxLength);
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        _platformUiContext->BeginTextInput();
        LOG_INFO(
            "[OpenRCT2Touch] text-input: active=%d screen_supported=%d screen_requested=%d", SDL_IsTextInputActive(),
            SDL_HasScreenKeyboardSupport(), SDL_IsScreenKeyboardShown(_window));
#endif
        return session;
    }

    void StopTextInput() override
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        _platformUiContext->EndTextInput();
#endif
        _textComposition.Stop();
    }

    void ProcessMessages() override
    {
        _lastKeyPressed = 0;
        _cursorState.left &= ~CURSOR_CHANGED;
        _cursorState.middle &= ~CURSOR_CHANGED;
        _cursorState.right &= ~CURSOR_CHANGED;
        _cursorState.old = 0;

        SDL_Event e;
        while (SDL_PollEvent(&e))
        {
            switch (e.type)
            {
                case SDL_QUIT:
                    ContextQuit();
                    break;
                case SDL_WINDOWEVENT:
                    if (e.window.event == SDL_WINDOWEVENT_RESIZED
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                        || e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED
#endif
                    )
                    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                        // Event data1/data2 can be 0x0 or a stale orientation during
                        // rotation. TriggerResize reads SDL_GetWindowSize.
                        TriggerResize();
#else
                        LOG_VERBOSE("New Window size: %ux%u\n", e.window.data1, e.window.data2);
                        OnResize(e.window.data1, e.window.data2);
#endif
                    }

                    switch (e.window.event)
                    {
                        case SDL_WINDOWEVENT_RESIZED:
                        case SDL_WINDOWEVENT_MOVED:
                        case SDL_WINDOWEVENT_MAXIMIZED:
                        case SDL_WINDOWEVENT_RESTORED:
                        {
                            // Update default display index
                            int32_t displayIndex = SDL_GetWindowDisplayIndex(_window);
                            if (displayIndex != Config::Get().general.defaultDisplay)
                            {
                                Config::Get().general.defaultDisplay = displayIndex;
                                Config::Save();
                            }
                            break;
                        }
                    }

                    if (Config::Get().sound.audioFocus)
                    {
                        if (e.window.event == SDL_WINDOWEVENT_FOCUS_GAINED)
                        {
                            SetAudioVolume(1);
                        }
                        if (e.window.event == SDL_WINDOWEVENT_FOCUS_LOST)
                        {
                            SetAudioVolume(0);
                        }
                    }
                    break;
                case SDL_MOUSEMOTION:
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    if (e.motion.which == SDL_TOUCH_MOUSEID)
                    {
                        // SDL mirrors finger motion as mouse motion on iOS. The touch gesture layer has already
                        // applied pan direction and sensitivity, so accepting this event would overwrite both.
                        break;
                    }
#endif
                    _cursorState.position = MapWindowPointToCanvas(static_cast<float>(e.motion.x), static_cast<float>(e.motion.y));
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    _cursorState.touch = false;
#endif
                    break;
                case SDL_MOUSEWHEEL:
                    if (_inGameConsole.IsOpen())
                    {
                        _inGameConsole.Scroll(e.wheel.y * 3); // Scroll 3 lines at a time
                        break;
                    }
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    if (ViewportFindFromPoint(_cursorState.position) != nullptr)
                    {
                        AddTrackpadViewportWheel(-e.wheel.y);
                    }
                    else
                    {
                        _trackpadViewportWheelAccumulator = 0;
                        _cursorState.wheel -= e.wheel.y;
                    }
#else
                    _cursorState.wheel -= e.wheel.y;
#endif
                    break;
                case SDL_MOUSEBUTTONDOWN:
                {
                    if (e.button.which == SDL_TOUCH_MOUSEID)
                    {
                        break;
                    }
                    ScreenCoordsXY mousePos = MapWindowPointToCanvas(static_cast<float>(e.button.x), static_cast<float>(e.button.y));
                    switch (e.button.button)
                    {
                        case SDL_BUTTON_LEFT:
                            StoreMouseInput(MouseState::leftPress, mousePos);
                            _cursorState.left = CURSOR_PRESSED;
                            _cursorState.old = 1;
                            break;
                        case SDL_BUTTON_MIDDLE:
                            _cursorState.middle = CURSOR_PRESSED;
                            break;
                        case SDL_BUTTON_RIGHT:
                            StoreMouseInput(MouseState::rightPress, mousePos);
                            _cursorState.right = CURSOR_PRESSED;
                            _cursorState.old = 2;
                            break;
                    }
                    _cursorState.touch = false;

                    {
                        InputEvent ie;
                        ie.deviceKind = InputDeviceKind::mouse;
                        ie.modifiers = SDL_GetModState();
                        ie.button = e.button.button;
                        ie.state = InputEventState::down;
                        _inputManager.queueInputEvent(std::move(ie));
                    }
                    break;
                }
                case SDL_MOUSEBUTTONUP:
                {
                    if (e.button.which == SDL_TOUCH_MOUSEID)
                    {
                        break;
                    }
                    ScreenCoordsXY mousePos = MapWindowPointToCanvas(static_cast<float>(e.button.x), static_cast<float>(e.button.y));
                    switch (e.button.button)
                    {
                        case SDL_BUTTON_LEFT:
                            StoreMouseInput(MouseState::leftRelease, mousePos);
                            _cursorState.left = CURSOR_RELEASED;
                            _cursorState.old = 3;
                            break;
                        case SDL_BUTTON_MIDDLE:
                            _cursorState.middle = CURSOR_RELEASED;
                            break;
                        case SDL_BUTTON_RIGHT:
                            StoreMouseInput(MouseState::rightRelease, mousePos);
                            _cursorState.right = CURSOR_RELEASED;
                            _cursorState.old = 4;
                            break;
                    }
                    _cursorState.touch = false;

                    {
                        InputEvent ie;
                        ie.deviceKind = InputDeviceKind::mouse;
                        ie.modifiers = SDL_GetModState();
                        ie.button = e.button.button;
                        ie.state = InputEventState::release;
                        _inputManager.queueInputEvent(std::move(ie));
                    }
                    break;
                }
                // Apple sends touchscreen events for trackpads, so ignore these events on macOS
#ifndef __MACOSX__
                case SDL_FINGERMOTION:
    #if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    HandleTouchMotion(e.tfinger);
    #else
                    _cursorState.position = { static_cast<int32_t>(e.tfinger.x * _width),
                                              static_cast<int32_t>(e.tfinger.y * _height) };
    #endif
                    break;
                case SDL_FINGERDOWN:
                {
    #if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    HandleTouchDown(e.tfinger);
    #else
                    ScreenCoordsXY fingerPos = { static_cast<int32_t>(e.tfinger.x * _width),
                                                 static_cast<int32_t>(e.tfinger.y * _height) };

                    _cursorState.touchIsDouble
                        = (!_cursorState.touchIsDouble
                           && e.tfinger.timestamp - _cursorState.touchDownTimestamp < kTouchDoubleTimeout);

                    if (_cursorState.touchIsDouble)
                    {
                        StoreMouseInput(MouseState::rightPress, fingerPos);
                        _cursorState.right = CURSOR_PRESSED;
                        _cursorState.old = 2;
                    }
                    else
                    {
                        StoreMouseInput(MouseState::leftPress, fingerPos);
                        _cursorState.left = CURSOR_PRESSED;
                        _cursorState.old = 1;
                    }
                    _cursorState.touch = true;
                    _cursorState.touchDownTimestamp = e.tfinger.timestamp;
    #endif
                    break;
                }
                case SDL_FINGERUP:
                {
    #if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    HandleTouchUp(e.tfinger);
    #else
                    ScreenCoordsXY fingerPos = { static_cast<int32_t>(e.tfinger.x * _width),
                                                 static_cast<int32_t>(e.tfinger.y * _height) };

                    if (_cursorState.touchIsDouble)
                    {
                        StoreMouseInput(MouseState::rightRelease, fingerPos);
                        _cursorState.right = CURSOR_RELEASED;
                        _cursorState.old = 4;
                    }
                    else
                    {
                        StoreMouseInput(MouseState::leftRelease, fingerPos);
                        _cursorState.left = CURSOR_RELEASED;
                        _cursorState.old = 3;
                    }
                    _cursorState.touch = true;
    #endif
                    break;
                }
#endif
                case SDL_KEYDOWN:
                {
#ifndef __MACOSX__
                    // Ignore winkey keydowns. Handles edge case where tiling
                    // window managers don't eat the keypresses when changing
                    // workspaces.
                    if (SDL_GetModState() & KMOD_GUI)
                    {
                        break;
                    }
#endif
                    _textComposition.HandleMessage(&e);
                    auto ie = GetInputEventFromSDLEvent(e);
                    ie.state = InputEventState::down;
                    _inputManager.queueInputEvent(std::move(ie));
                    break;
                }
                case SDL_KEYUP:
                {
                    auto ie = GetInputEventFromSDLEvent(e);
                    ie.state = InputEventState::release;
                    _inputManager.queueInputEvent(std::move(ie));
                    break;
                }
                case SDL_MULTIGESTURE:
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
                    // iPadOS touch handling classifies one- and two-finger motion as pan or pinch above.
#else
                    if (e.mgesture.numFingers == 2)
                    {
                        if (e.mgesture.timestamp > _lastGestureTimestamp + 1000)
                        {
                            _gestureRadius = 0;
                        }
                        _lastGestureTimestamp = e.mgesture.timestamp;
                        _gestureRadius += e.mgesture.dDist;

                        // Zoom gesture
                        constexpr int32_t tolerance = 128;
                        int32_t gesturePixels = static_cast<int32_t>(_gestureRadius * _width);
                        if (abs(gesturePixels) > tolerance)
                        {
                            _gestureRadius = 0;
                            Windows::MainWindowZoom(gesturePixels > 0, true);
                        }
                    }
#endif
                    break;
                case SDL_TEXTEDITING:
                    _textComposition.HandleMessage(&e);
                    break;
                case SDL_TEXTINPUT:
                    _textComposition.HandleMessage(&e);
                    break;
                default:
                {
                    if (_platformUiContext->HandleSdlEvent(e))
                    {
                        break;
                    }
                    _inputManager.queueInputEvent(e);
                    break;
                }
            }
        }

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        HandleTouchHold();
#endif

        _cursorState.any = _cursorState.left | _cursorState.middle | _cursorState.right;

        // Updates the state of the keys
        int32_t numKeys = 256;
        _keysState = SDL_GetKeyboardState(&numKeys);
    }

    /**
     * Helper function to set various render target features.
     * Does not get triggered on resize, but rather manually on config changes.
     */
    void TriggerResize() override
    {
        char scaleQualityBuffer[4];
        _scaleQuality = ScaleQuality::smoothNearestNeighbour;
        if (Config::Get().general.windowScale == std::floor(Config::Get().general.windowScale))
        {
            _scaleQuality = ScaleQuality::nearestNeighbour;
        }

        ScaleQuality scaleQuality = _scaleQuality;
        if (_scaleQuality == ScaleQuality::smoothNearestNeighbour)
        {
            scaleQuality = ScaleQuality::linear;
        }
        snprintf(scaleQualityBuffer, sizeof(scaleQualityBuffer), "%d", static_cast<int32_t>(scaleQuality));
        SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, scaleQualityBuffer);

        int32_t width, height;
        SDL_GetWindowSize(_window, &width, &height);
        OnResize(width, height);
    }

    void CreateWindow() override
    {
        SDL_SetHint(SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS, Config::Get().general.minimizeFullscreenFocusLoss ? "1" : "0");

        // Set window position to default display
        int32_t defaultDisplay = std::clamp(Config::Get().general.defaultDisplay, 0, 0xFFFF);
        auto windowPos = ScreenCoordsXY{ static_cast<int32_t>(SDL_WINDOWPOS_UNDEFINED_DISPLAY(defaultDisplay)),
                                         static_cast<int32_t>(SDL_WINDOWPOS_UNDEFINED_DISPLAY(defaultDisplay)) };

        CreateWindow(windowPos);

        // Check if steam overlay renderer is loaded into the process
        _steamOverlayActive = _platformUiContext->IsSteamOverlayAttached();
    }

    void CloseWindow() override
    {
        DrawingEngineDispose();
        if (_window != nullptr)
        {
            SDL_DestroyWindow(_window);
            _window = nullptr;
        }
    }

    void RecreateWindow() override
    {
        // Use the position of the current window for the new window
        ScreenCoordsXY windowPos;
        SDL_SetWindowFullscreen(_window, 0);
        SDL_GetWindowPosition(_window, &windowPos.x, &windowPos.y);

        CloseWindow();
        CreateWindow(windowPos);
    }

    void ShowMessageBox(const std::string& message) override
    {
        _platformUiContext->ShowMessageBox(_window, message);
    }

    int32_t ShowMessageBox(
        const std::string& title, const std::string& message, const std::vector<std::string>& options) override
    {
        auto message_box_button_data = std::make_unique<SDL_MessageBoxButtonData[]>(options.size());
        for (size_t i = 0; i < options.size(); i++)
        {
            message_box_button_data[i].buttonid = static_cast<int>(i);
            message_box_button_data[i].text = options[i].c_str();
        }

        SDL_MessageBoxData message_box_data{};
        message_box_data.window = _window;
        message_box_data.title = title.c_str();
        message_box_data.message = message.c_str();
        message_box_data.numbuttons = static_cast<int>(options.size());
        message_box_data.buttons = message_box_button_data.get();

        int buttonid{};

        SDL_ShowMessageBox(&message_box_data, &buttonid);

        return buttonid;
    }

    bool HasMenuSupport() override
    {
        return _platformUiContext->HasMenuSupport();
    }

    int32_t ShowMenuDialog(const std::vector<std::string>& options, const std::string& title, const std::string& text) override
    {
        return _platformUiContext->ShowMenuDialog(options, title, text);
    }

    void OpenFolder(const std::string& path) override
    {
        _platformUiContext->OpenFolder(path);
    }

    void OpenURL(const std::string& url) override
    {
        _platformUiContext->OpenURL(url);
    }

    std::string ShowFileDialog(const FileDialogDesc& desc) override
    {
        return _platformUiContext->ShowFileDialog(_window, desc);
    }

    std::string ShowDirectoryDialog(const std::string& title) override
    {
        return _platformUiContext->ShowDirectoryDialog(_window, title);
    }

    bool HasFilePicker() const override
    {
        return _platformUiContext->HasFilePicker();
    }

    IWindowManager* GetWindowManager() override
    {
        return _windowManager.get();
    }

    bool SetClipboardText(const utf8* target) override
    {
#ifndef __EMSCRIPTEN__
        return (SDL_SetClipboardText(target) == 0);
#else
        return (
            MAIN_THREAD_EM_ASM_INT(
                {
                    try
                    {
                        navigator.clipboard.writeText(UTF8ToString($0));
                        return 0;
                    }
                    catch (e)
                    {
                        return -1;
                    };
                },
                target)
            == 0);
#endif
    }

    ITitleSequencePlayer* GetTitleSequencePlayer() override
    {
        if (_titleSequencePlayer == nullptr)
        {
            _titleSequencePlayer = Title::CreateTitleSequencePlayer();
        }
        return _titleSequencePlayer.get();
    }

private:
    void LogSDLVersion()
    {
        SDL_version version{};
        SDL_GetVersion(&version);
        LOG_VERBOSE("SDL2 version: %d.%d.%d", version.major, version.minor, version.patch);
    }

    void InferDisplayDPI()
    {
        auto& config = Config::Get().general;
        if (!config.inferDisplayDPI)
            return;

        int wWidth, wHeight;
        SDL_GetWindowSize(_window, &wWidth, &wHeight);

        auto renderer = SDL_GetRenderer(_window);
        int rWidth, rHeight;
        if (SDL_GetRendererOutputSize(renderer, &rWidth, &rHeight) == 0)
            config.windowScale = rWidth / wWidth;

        config.inferDisplayDPI = false;
        Config::Save();
    }

    void CreateWindow(const ScreenCoordsXY& windowPos)
    {
#ifdef __EMSCRIPTEN__
        MAIN_THREAD_EM_ASM({
            Module.canvas.width = window.innerWidth;
            Module.canvas.height = window.innerHeight;
        });
        int32_t width = 0;
        int32_t height = 0;
        emscripten_get_canvas_element_size("!canvas", &width, &height);
#else
        // Get saved window size
        int32_t width = Config::Get().general.windowWidth;
        int32_t height = Config::Get().general.windowHeight;
#endif

        // Set defaults if size is invalid
        if (width <= 0)
            width = 1280;
        if (height <= 0)
            height = 720;

        // Create window in window first rather than fullscreen so we have the display the window is on first
        uint32_t flags = SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI;
        if (Config::Get().general.drawingEngine == DrawingEngine::openGL)
        {
            flags |= SDL_WINDOW_OPENGL;
        }

        _window = SDL_CreateWindow(OPENRCT2_NAME, windowPos.x, windowPos.y, width, height, flags);
        if (_window == nullptr)
        {
            const char* error = SDL_GetError();
            std::string errorMessage = String::stdFormat(
                "SDL_CreateWindow(" OPENRCT2_NAME ", %d, %d, %d, %d, %d) failed: %s", windowPos.x, windowPos.y, width, height,
                flags, error);
            SDLException::Throw(errorMessage.c_str());
        }

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        SDL_GetWindowSize(_window, &width, &height);
#endif

        ApplyScreenSaverLockSetting();

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        // UIKit owns the fullscreen window; a desktop minimum size would reject iPhone widths.
#else
        SDL_SetWindowMinimumSize(_window, 720, 480);
#endif
        SetCursorTrap(Config::Get().general.trapCursor);
        _platformUiContext->SetWindowIcon(_window);
        _platformUiContext->AttachNativeOverlay(_window);

        // Initialise the surface, palette and draw buffer
        DrawingEngineInit();
        InferDisplayDPI();
        OnResize(width, height);

        UpdateFullscreenResolutions();

        SetFullscreenMode(static_cast<FullscreenMode>(Config::Get().general.fullscreenMode));
        TriggerResize();
    }

    void OnResize(int32_t width, int32_t height)
    {
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        // Config, SDL_CreateWindow, and SIZE_CHANGED can disagree with UIKit
        // during rotation. Prefer the window scene size, not SDL_GetWindowSize:
        // a SwiftUI Menu becomes the key window and reports a portrait frame.
        if (_window != nullptr)
        {
            RestoreIosCanvasFrame();
            const IosSafeArea canvas = GetIosSafeArea();
            if (canvas.windowWidth > 0 && canvas.windowHeight > 0)
            {
                width = canvas.windowWidth;
                height = canvas.windowHeight;
            }
            else
            {
                int32_t liveWidth = 0;
                int32_t liveHeight = 0;
                SDL_GetWindowSize(_window, &liveWidth, &liveHeight);
                if (liveWidth > 0 && liveHeight > 0)
                {
                    width = liveWidth;
                    height = liveHeight;
                }
            }
        }
#endif
        // Scale the native window size to the game's canvas size
        const int32_t newWidth = static_cast<int32_t>(width / Config::Get().general.windowScale);
        const int32_t newHeight = static_cast<int32_t>(height / Config::Get().general.windowScale);
#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        // SIZE_CHANGED can arrive at 0x0 during rotation; skip that and duplicates.
        if (newWidth <= 0 || newHeight <= 0 || (newWidth == _width && newHeight == _height))
        {
            return;
        }
#endif
        _width = newWidth;
        _height = newHeight;

        DrawingEngineResize();

        uint32_t flags = SDL_GetWindowFlags(_window);
        if ((flags & SDL_WINDOW_MINIMIZED) == 0)
        {
            WindowResizeGui(_width, _height);
            Windows::WindowRelocateWindows(_width, _height);
        }

        GfxInvalidateScreen();

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_IOS
        // UIKit owns the window size; persisting it made the next launch create
        // a canvas in the previous orientation before the first SIZE_CHANGED.
#else
        // Check if the window has been resized in windowed mode and update the config file accordingly
        int32_t nonWindowFlags =
#ifndef __MACOSX__
            SDL_WINDOW_MAXIMIZED |
#endif
            SDL_WINDOW_MINIMIZED | SDL_WINDOW_FULLSCREEN | SDL_WINDOW_FULLSCREEN_DESKTOP;

        if (!(flags & nonWindowFlags))
        {
            if (width != Config::Get().general.windowWidth || height != Config::Get().general.windowHeight)
            {
                Config::Get().general.windowWidth = width;
                Config::Get().general.windowHeight = height;
                Config::Save();
            }
        }
#endif
    }

    void UpdateFullscreenResolutions()
    {
        // Query number of display modes
        int32_t displayIndex = SDL_GetWindowDisplayIndex(_window);
        int32_t numDisplayModes = SDL_GetNumDisplayModes(displayIndex);

        // Get desktop aspect ratio
        SDL_DisplayMode mode;
        SDL_GetDesktopDisplayMode(displayIndex, &mode);

        // Get resolutions
        auto resolutions = std::vector<Resolution>();
        float desktopAspectRatio = static_cast<float>(mode.w) / mode.h;
        for (int32_t i = 0; i < numDisplayModes; i++)
        {
            SDL_GetDisplayMode(displayIndex, i, &mode);
            if (mode.w > 0 && mode.h > 0)
            {
                float aspectRatio = static_cast<float>(mode.w) / mode.h;
                if (std::fabs(desktopAspectRatio - aspectRatio) < 0.1f)
                {
                    resolutions.push_back({ mode.w, mode.h });
                }
            }
        }

        // Sort by area
        std::sort(resolutions.begin(), resolutions.end(), [](const Resolution& a, const Resolution& b) -> bool {
            int32_t areaA = a.Width * a.Height;
            int32_t areaB = b.Width * b.Height;
            return areaA < areaB;
        });

        // Remove duplicates
        auto last = std::unique(resolutions.begin(), resolutions.end(), [](const Resolution& a, const Resolution& b) -> bool {
            return (a.Width == b.Width && a.Height == b.Height);
        });
        resolutions.erase(last, resolutions.end());

        // Update config fullscreen resolution if not set
        if (!resolutions.empty()
            && (Config::Get().general.fullscreenWidth == -1 || Config::Get().general.fullscreenHeight == -1))
        {
            Config::Get().general.fullscreenWidth = resolutions.back().Width;
            Config::Get().general.fullscreenHeight = resolutions.back().Height;
        }

        _fsResolutions = resolutions;
    }

    Resolution GetClosestResolution(int32_t inWidth, int32_t inHeight)
    {
        Resolution result = { 640, 480 };
        int32_t closestAreaDiff = -1;
        int32_t destinationArea = inWidth * inHeight;
        for (const Resolution& resolution : _fsResolutions)
        {
            // Check if exact match
            if (resolution.Width == inWidth && resolution.Height == inHeight)
            {
                result = resolution;
                break;
            }

            // Check if area is closer to best match
            int32_t areaDiff = std::abs((resolution.Width * resolution.Height) - destinationArea);
            if (closestAreaDiff == -1 || areaDiff < closestAreaDiff)
            {
                closestAreaDiff = areaDiff;
                result = resolution;
            }
        }
        return result;
    }

    uint32_t GetWindowFlags()
    {
        return SDL_GetWindowFlags(_window);
    }

    static void DrawWeatherWindow(
        RenderTarget& rt, IWeatherDrawer* weatherDrawer, WindowBase* original_w, int16_t left, int16_t right, int16_t top,
        int16_t bottom, DrawWeatherFunc drawFunc)
    {
        WindowBase* w{};
        auto itStart = WindowGetIterator(original_w);
        for (auto it = std::next(itStart);; it++)
        {
            if (it == gWindowList.end())
            {
                // Loop ended, draw weather for original_w
                auto vp = original_w->viewport;
                if (vp != nullptr)
                {
                    left = std::max<int16_t>(left, vp->pos.x);
                    right = std::min<int16_t>(right, vp->pos.x + vp->width);
                    top = std::max<int16_t>(top, vp->pos.y);
                    bottom = std::min<int16_t>(bottom, vp->pos.y + vp->height);
                    if (left < right && top < bottom)
                    {
                        auto width = right - left;
                        auto height = bottom - top;
                        drawFunc(rt, weatherDrawer, left, top, width, height);
                    }
                }
                return;
            }

            w = it->get();

            if (w->flags.has(WindowFlag::dead))
            {
                continue;
            }

            if (right <= w->windowPos.x || bottom <= w->windowPos.y)
            {
                continue;
            }

            if (w->right() <= left || w->bottom() <= top)
            {
                continue;
            }

            if (left >= w->windowPos.x)
            {
                break;
            }

            DrawWeatherWindow(rt, weatherDrawer, original_w, left, w->windowPos.x, top, bottom, drawFunc);

            left = w->windowPos.x;
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, bottom, drawFunc);
            return;
        }

        auto wRight = w->right();
        if (right > wRight)
        {
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, wRight, top, bottom, drawFunc);

            left = wRight;
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, bottom, drawFunc);
            return;
        }

        if (top < w->windowPos.y)
        {
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, w->windowPos.y, drawFunc);

            top = w->windowPos.y;
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, bottom, drawFunc);
            return;
        }

        auto wBottom = w->bottom();
        if (bottom > wBottom)
        {
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, wBottom, drawFunc);

            top = wBottom;
            DrawWeatherWindow(rt, weatherDrawer, original_w, left, right, top, bottom, drawFunc);
            return;
        }
    }

    InputEvent GetInputEventFromSDLEvent(const SDL_Event& e)
    {
        InputEvent ie;
        ie.deviceKind = InputDeviceKind::keyboard;
        ie.modifiers = e.key.keysym.mod;
        ie.button = e.key.keysym.sym;

        // Handle dead keys
        if (ie.button == (SDLK_SCANCODE_MASK | 0))
        {
            switch (e.key.keysym.scancode)
            {
                case SDL_SCANCODE_APOSTROPHE:
                    ie.button = '\'';
                    break;
                case SDL_SCANCODE_GRAVE:
                    ie.button = '`';
                    break;
                default:
                    break;
            }
        }

        return ie;
    }

    void SetAudioVolume(float value)
    {
        auto& audioContext = GetContext()->GetAudioContext();
        auto* mixer = audioContext.GetMixer();
        if (mixer != nullptr)
        {
            mixer->SetVolume(value);
        }
    }
};

std::unique_ptr<IUiContext> Ui::CreateUiContext(IPlatformEnvironment& env)
{
    return std::make_unique<UiContext>(env);
}

InGameConsole& Ui::GetInGameConsole()
{
    auto& uiContext = static_cast<UiContext&>(GetContext()->GetUiContext());
    return uiContext.GetInGameConsole();
}

InputManager& Ui::GetInputManager()
{
    auto& uiContext = static_cast<UiContext&>(GetContext()->GetUiContext());
    return uiContext.GetInputManager();
}

ShortcutManager& Ui::GetShortcutManager()
{
    auto& uiContext = static_cast<UiContext&>(GetContext()->GetUiContext());
    return uiContext.GetShortcutManager();
}
