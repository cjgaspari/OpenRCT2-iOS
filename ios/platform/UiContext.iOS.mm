/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <openrct2-ui/UiContext.h>

    #include <SDL.h>
    #include <UIKit/UIKit.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/ui/UiContext.h>

namespace OpenRCT2::Ui
{
    class iOSContext final : public IPlatformUiContext
    {
    public:
        iOSContext()
        {
            SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
            SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "2");
        }

        void SetWindowIcon([[maybe_unused]] SDL_Window* window) override
        {
        }

        bool IsSteamOverlayAttached() override
        {
            return false;
        }

        void ShowMessageBox(SDL_Window* window, const std::string& message) override
        {
            LOG_INFO("%s", message.c_str());
            SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_WARNING, "OpenRCT2 Touch", message.c_str(), window);
        }

        bool HasMenuSupport() override
        {
            return false;
        }

        int32_t ShowMenuDialog(
            [[maybe_unused]] const std::vector<std::string>& options, [[maybe_unused]] const std::string& title,
            [[maybe_unused]] const std::string& text) override
        {
            return -1;
        }

        void OpenFolder([[maybe_unused]] const std::string& path) override
        {
            LOG_WARNING("Opening folders is not supported on iOS yet.");
        }

        void OpenURL(const std::string& url) override
        {
            @autoreleasepool
            {
                NSURL* target = [NSURL URLWithString:[NSString stringWithUTF8String:url.c_str()]];
                if (target != nil)
                {
                    [UIApplication.sharedApplication openURL:target options:@{} completionHandler:nil];
                }
            }
        }

        std::string ShowFileDialog(
            [[maybe_unused]] SDL_Window* window, [[maybe_unused]] const FileDialogDesc& desc) override
        {
            LOG_WARNING("The iOS document picker is not implemented yet.");
            return {};
        }

        std::string ShowDirectoryDialog(
            [[maybe_unused]] SDL_Window* window, [[maybe_unused]] const std::string& title) override
        {
            LOG_WARNING("The iOS document picker is not implemented yet.");
            return {};
        }

        bool HasFilePicker() const override
        {
            return false;
        }
    };

    std::unique_ptr<IPlatformUiContext> CreatePlatformUiContext()
    {
        return std::make_unique<iOSContext>();
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
