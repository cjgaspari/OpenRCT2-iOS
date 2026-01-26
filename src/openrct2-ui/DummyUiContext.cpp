/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#ifdef OPENRCT2_VISIONOS

    #include "DummyUiContext.h"

    #include "CursorRepository.h"
    #include "TextComposition.h"
    #include "UiStringIds.h"
    #include "WindowManager.h"
    #include "drawing/engines/DrawingEngineFactory.hpp"
    #include "input/ShortcutManager.h"
    #include "interface/InGameConsole.h"
    #include "interface/Theme.h"
    #include "interface/Viewport.h"
    #include "scripting/UiExtensions.h"
    #include "visionos.h"

    #include <memory>
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
    #include <openrct2/interface/Chat.h>
    #include <openrct2/platform/Platform.h>
    #include <openrct2/scenes/title/TitleSequencePlayer.h>
    #include <openrct2/scripting/ScriptEngine.h>
    #include <openrct2/ui/UiContext.h>
    #include <openrct2/ui/WindowManager.h>
    #include <openrct2/world/Location.hpp>
    #include <vector>

namespace OpenRCT2::Ui
{
    // Dummy implementations for supporting classes

    class DummyDrawingEngineFactory final : public IDrawingEngineFactory
    {
    public:
        std::unique_ptr<IDrawingEngine> Create(DrawingEngine engine, IUiContext& uiContext) override
        {
            // Force software engine
            return DrawingEngineFactory::Create(DrawingEngine::SoftwareWithHardwareDisplay, uiContext);
        }
    };

    class DummyWindowManager final : public IWindowManager
    {
    public:
        void Init() override
        {
            LOG_INFO("[DummyWindowManager] Init called");
        }
        void UpdateMapTooltip() override
        {
        }
        WindowBase* OpenWindow(WindowClass wc) override
        {
            LOG_INFO("[DummyWindowManager] OpenWindow called for class %d", static_cast<int>(wc));
            return nullptr;
        }
        WindowBase* OpenWindowView(WindowView view) override
        {
            LOG_INFO("[DummyWindowManager] OpenWindowView called for view %d", static_cast<int>(view));
            return nullptr;
        }
        WindowBase* OpenDetails(WindowDetail type, int32_t id) override
        {
            LOG_INFO("[DummyWindowManager] OpenDetails called for type %d, id %d", static_cast<int>(type), id);
            return nullptr;
        }
        WindowBase* OpenIntent(Intent* intent) override
        {
            LOG_INFO("[DummyWindowManager] OpenIntent called");
            return nullptr;
        }
        void BroadcastIntent(Intent& intent) override
        {
        }
        void ForceClose(WindowClass windowClass) override
        {
        }
        void UpdateAll() override
        {
        }
        void InvalidateByClass(WindowClass windowClass) override
        {
            LOG_INFO("[DummyWindowManager] InvalidateByClass called for class %d", static_cast<int>(windowClass));
        }
        void InvalidateWidget(WindowBase* window, WidgetIndex widgetIndex) override
        {
        }
        void InvalidateRect(const ScreenRect& rect) override
        {
        }
        void BringToFront(WindowBase* window) override
        {
        }
        void DispatchUpdateAll() override
        {
        }
        void HandleInput() override
        {
        }
        void HandleKeyboard(bool isTitle) override
        {
        }
        void CloseByClass(WindowClass windowClass) override
        {
            LOG_INFO("[DummyWindowManager] CloseByClass called for class %d", static_cast<int>(windowClass));
        }
        void CloseTop() override
        {
            LOG_INFO("[DummyWindowManager] CloseTop called");
        }
        void CloseAll() override
        {
            LOG_INFO("[DummyWindowManager] CloseAll called");
        }
        void CloseAllExceptClass(WindowClass windowClass) override
        {
            LOG_INFO("[DummyWindowManager] CloseAllExceptClass called for class %d", static_cast<int>(windowClass));
        }
        WindowBase* FindByClass(WindowClass windowClass) override
        {
            LOG_INFO("[DummyWindowManager] FindByClass called for class %d", static_cast<int>(windowClass));
            return nullptr;
        }
        WindowBase* FindByNumber(WindowClass windowClass, rct_windownumber number) override
        {
            LOG_INFO("[DummyWindowManager] FindByNumber called for class %d, number %d", static_cast<int>(windowClass), number);
            return nullptr;
        }
        WindowBase* FindFromPoint(const ScreenCoordsXY& screenCoords) override
        {
            LOG_INFO("[DummyWindowManager] FindFromPoint called for coords (%d, %d)", screenCoords.x, screenCoords.y);
            return nullptr;
        }
        void ProcessMouseWheel() override
        {
        }
        void SetMainView(ScreenCoordsXY* view) override
        {
            LOG_INFO("[DummyWindowManager] SetMainView called");
        }
        void ScrollAll(WindowClass windowClass, int32_t scrollIndex, int32_t scrollAmount) override
        {
        }
        void InvalidateAll() override
        {
        }
        void RepositionAll() override
        {
        }
    };

    class DummyPlatformUiContext final : public IPlatformUiContext
    {
    public:
        void SetWindowIcon(void* window) override
        {
        }
        bool IsSteamOverlayAttached() override
        {
            return false;
        }
        void ShowMessageBox(void* window, const std::string& message) override
        {
            VISIONOS_LOG_INFO("ShowMessageBox: %s", message.c_str());
            LOG_INFO("[DummyPlatformUiContext] ShowMessageBox: %s", message.c_str());
        }
        bool HasMenuSupport() override
        {
            return false;
        }
        int32_t ShowMenuDialog(
            const std::vector<std::string>& options, const std::string& title, const std::string& text) override
        {
            VISIONOS_LOG_INFO("ShowMenuDialog: %s - %s", title.c_str(), text.c_str());
            return 0;
        }
        void OpenFolder(const std::string& path) override
        {
            VISIONOS_LOG_INFO("OpenFolder: %s", path.c_str());
        }
        void OpenURL(const std::string& url) override
        {
            VISIONOS_LOG_INFO("OpenURL: %s", url.c_str());
        }
        std::string ShowFileDialog(void* window, const FileDialogDesc& desc) override
        {
            VISIONOS_LOG_INFO("ShowFileDialog");
            return "";
        }
        std::string ShowDirectoryDialog(void* window, const std::string& title) override
        {
            return "";
        }
        bool HasFilePicker() const override
        {
            return false;
        }
    };

    // Static dummy data
    static CursorState dummyCursorState = {};
    static uint8_t dummyKeys[256] = {};
    static std::vector<Resolution> dummyResolutions = {};

    DummyUiContext::DummyUiContext()
    {
        VISIONOS_LOG_INFO("DummyUiContext created");
        LOG_INFO("[DummyUiContext] Constructor called");
    }

    void DummyUiContext::InitialiseScriptExtensions()
    {
    #ifdef ENABLE_SCRIPTING
        auto& scriptEngine = GetContext()->GetScriptEngine();
        Scripting::UiScriptExtensions::Extend(scriptEngine);
    #endif
    }

    void DummyUiContext::Tick()
    {
        // No-op
    }

    void DummyUiContext::Draw(RenderTarget& rt)
    {
        // No-op
    }

    void* DummyUiContext::GetWindow()
    {
        VISIONOS_LOG_INFO("GetWindow called");
        LOG_INFO("[DummyUiContext] GetWindow called");
        return nullptr;
    }

    int32_t DummyUiContext::GetWidth()
    {
        VISIONOS_LOG_INFO("GetWidth called");
        LOG_INFO("[DummyUiContext] GetWidth called");
        return _width;
    }

    int32_t DummyUiContext::GetHeight()
    {
        VISIONOS_LOG_INFO("GetHeight called");
        LOG_INFO("[DummyUiContext] GetHeight called");
        return _height;
    }

    ScaleQuality DummyUiContext::GetScaleQuality()
    {
        VISIONOS_LOG_INFO("GetScaleQuality called");
        LOG_INFO("[DummyUiContext] GetScaleQuality called");
        return _scaleQuality;
    }

    void DummyUiContext::SetFullscreenMode(FullscreenMode mode)
    {
        VISIONOS_LOG_INFO("SetFullscreenMode: %d", static_cast<int>(mode));
        LOG_INFO("[DummyUiContext] SetFullscreenMode: %d", static_cast<int>(mode));
    }

    const std::vector<Resolution>& DummyUiContext::GetFullscreenResolutions()
    {
        VISIONOS_LOG_INFO("GetFullscreenResolutions called");
        LOG_INFO("[DummyUiContext] GetFullscreenResolutions called");
        return dummyResolutions;
    }

    bool DummyUiContext::HasFocus()
    {
        VISIONOS_LOG_INFO("HasFocus called");
        LOG_INFO("[DummyUiContext] HasFocus called");
        return _hasFocus;
    }

    bool DummyUiContext::IsMinimised()
    {
        VISIONOS_LOG_INFO("IsMinimised called");
        LOG_INFO("[DummyUiContext] IsMinimised called");
        return false;
    }

    bool DummyUiContext::IsSteamOverlayActive()
    {
        return false;
    }

    const CursorState* DummyUiContext::GetCursorState()
    {
        return &dummyCursorState;
    }

    const uint8_t* DummyUiContext::GetKeysState()
    {
        return dummyKeys;
    }

    const uint8_t* DummyUiContext::GetKeysPressed()
    {
        return dummyKeys;
    }

    CursorID DummyUiContext::GetCursor()
    {
        return CursorID::Arrow;
    }

    void DummyUiContext::SetCursor(CursorID cursor)
    {
        // No-op
    }

    void DummyUiContext::SetCursorScale(uint8_t scale)
    {
        // No-op
    }

    void DummyUiContext::SetCursorVisible(bool value)
    {
        // No-op
    }

    ScreenCoordsXY DummyUiContext::GetCursorPosition()
    {
        return { 0, 0 };
    }

    void DummyUiContext::SetCursorPosition(const ScreenCoordsXY& cursorPosition)
    {
        // No-op
    }

    void DummyUiContext::SetCursorTrap(bool value)
    {
        // No-op
    }

    void DummyUiContext::SetKeysPressed(uint32_t keysym, uint8_t scancode)
    {
        // No-op
    }

    std::shared_ptr<IDrawingEngineFactory> DummyUiContext::GetDrawingEngineFactory()
    {
        return std::make_shared<DummyDrawingEngineFactory>();
    }

    void DummyUiContext::DrawWeatherAnimation(IWeatherDrawer* weatherDrawer, RenderTarget& rt, DrawWeatherFunc drawFunc)
    {
        // No-op
    }

    bool DummyUiContext::IsTextInputActive()
    {
        return false;
    }

    TextInputSession* DummyUiContext::StartTextInput(u8string& buffer, size_t maxLength)
    {
        return nullptr;
    }

    void DummyUiContext::StopTextInput()
    {
        // No-op
    }

    void DummyUiContext::ProcessMessages()
    {
        // No-op
    }

    void DummyUiContext::TriggerResize()
    {
        // No-op
    }

    void DummyUiContext::CreateWindow()
    {
        _windowCreated = true;
        VISIONOS_LOG_INFO("DummyUiContext: CreateWindow called");
        LOG_INFO("[DummyUiContext] CreateWindow called");
    }

    void DummyUiContext::CloseWindow()
    {
        _windowCreated = false;
        VISIONOS_LOG_INFO("DummyUiContext: CloseWindow called");
        LOG_INFO("[DummyUiContext] CloseWindow called");
    }

    void DummyUiContext::RecreateWindow()
    {
        VISIONOS_LOG_INFO("DummyUiContext: RecreateWindow called");
        LOG_INFO("[DummyUiContext] RecreateWindow called");
    }

    void DummyUiContext::ShowMessageBox(const std::string& message)
    {
        VISIONOS_LOG_INFO("ShowMessageBox: %s", message.c_str());
        LOG_INFO("[DummyUiContext] ShowMessageBox: %s", message.c_str());
    }

    int32_t DummyUiContext::ShowMessageBox(
        const std::string& title, const std::string& message, const std::vector<std::string>& options)
    {
        VISIONOS_LOG_INFO("ShowMessageBox: %s - %s", title.c_str(), message.c_str());
        LOG_INFO("[DummyUiContext] ShowMessageBox: %s - %s", title.c_str(), message.c_str());
        return 0;
    }

    bool DummyUiContext::HasMenuSupport()
    {
        return false;
    }

    int32_t DummyUiContext::ShowMenuDialog(
        const std::vector<std::string>& options, const std::string& title, const std::string& text)
    {
        VISIONOS_LOG_INFO("ShowMenuDialog: %s - %s", title.c_str(), text.c_str());
        LOG_INFO("[DummyUiContext] ShowMenuDialog: %s - %s", title.c_str(), text.c_str());
        return 0;
    }

    void DummyUiContext::OpenFolder(const std::string& path)
    {
        VISIONOS_LOG_INFO("OpenFolder: %s", path.c_str());
        LOG_INFO("[DummyUiContext] OpenFolder: %s", path.c_str());
    }

    void DummyUiContext::OpenURL(const std::string& url)
    {
        VISIONOS_LOG_INFO("OpenURL: %s", url.c_str());
        LOG_INFO("[DummyUiContext] OpenURL: %s", url.c_str());
    }

    std::string DummyUiContext::ShowFileDialog(const FileDialogDesc& desc)
    {
        VISIONOS_LOG_INFO("ShowFileDialog: %s", desc.Title.c_str());
        LOG_INFO("[DummyUiContext] ShowFileDialog: %s", desc.Title.c_str());
        return "";
    }

    std::string DummyUiContext::ShowDirectoryDialog(const std::string& title)
    {
        VISIONOS_LOG_INFO("ShowDirectoryDialog: %s", title.c_str());
        LOG_INFO("[DummyUiContext] ShowDirectoryDialog: %s", title.c_str());
        return "";
    }

    bool DummyUiContext::HasFilePicker() const
    {
        return false;
    }

    IWindowManager* DummyUiContext::GetWindowManager()
    {
        static DummyWindowManager dummyWindowManager;
        return &dummyWindowManager;
    }

    std::unique_ptr<IUiContext> CreateDummyUiContext()
    {
        LOG_INFO("[DummyUiContext] CreateDummyUiContext called");
        return std::make_unique<DummyUiContext>();
    }
} // namespace OpenRCT2::Ui

#endif // OPENRCT2_VISIONOS