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

    #include "NativeChrome.iOS.h"
    #include "RCT2Importer.iOS.h"

    #include <openrct2-ui/IosSafeArea.h>
    #include <openrct2-ui/UiContext.h>

    #include <SDL.h>
    #include <QuartzCore/CAMetalLayer.h>
    #include <UIKit/UIKit.h>
    #include <algorithm>
    #include <cmath>
    #include <cstring>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/ui/UiContext.h>

namespace OpenRCT2::Ui
{
    static void PushTextInput(NSString* text)
    {
        const char* utf8 = text.UTF8String;
        while (utf8 != nullptr && utf8[0] != '\0')
        {
            SDL_Event event{};
            event.type = SDL_TEXTINPUT;
            const size_t chunkLength = std::min(strlen(utf8), sizeof(event.text.text) - 1);
            memcpy(event.text.text, utf8, chunkLength);
            event.text.text[chunkLength] = '\0';
            SDL_PushEvent(&event);
            utf8 += chunkLength;
        }
    }

    static void PushKey(SDL_Keycode key, SDL_Scancode scancode)
    {
        SDL_Event event{};
        event.type = SDL_KEYDOWN;
        event.key.state = SDL_PRESSED;
        event.key.keysym.sym = key;
        event.key.keysym.scancode = scancode;
        SDL_PushEvent(&event);

        event.type = SDL_KEYUP;
        event.key.state = SDL_RELEASED;
        SDL_PushEvent(&event);
    }

    static UIWindowScene* GetForegroundWindowScene()
    {
        UIWindowScene* scene = nil;
        for (UIScene* candidate in UIApplication.sharedApplication.connectedScenes)
        {
            if (![candidate isKindOfClass:UIWindowScene.class])
            {
                continue;
            }
            UIWindowScene* windowScene = static_cast<UIWindowScene*>(candidate);
            if (windowScene.activationState == UISceneActivationStateForegroundActive)
            {
                return windowScene;
            }
            if (scene == nil)
            {
                scene = windowScene;
            }
        }
        return scene;
    }

    static BOOL ViewTreeHasMetalLayer(UIView* view)
    {
        if ([view.layer isKindOfClass:CAMetalLayer.class])
        {
            return YES;
        }
        for (UIView* child in view.subviews)
        {
            if (ViewTreeHasMetalLayer(child))
            {
                return YES;
            }
        }
        return NO;
    }

    static void PinMetalDrawable(UIView* view, CGSize points, CGFloat scale)
    {
        if ([view.layer isKindOfClass:CAMetalLayer.class])
        {
            CAMetalLayer* metal = static_cast<CAMetalLayer*>(view.layer);
            const CGSize pixels = CGSizeMake(points.width * scale, points.height * scale);
            if (fabs(metal.drawableSize.width - pixels.width) > 0.5
                || fabs(metal.drawableSize.height - pixels.height) > 0.5)
            {
                metal.drawableSize = pixels;
            }
        }
        for (UIView* child in view.subviews)
        {
            PinMetalDrawable(child, points, scale);
        }
    }

    static void PinViewToSize(UIView* view, CGSize size, CGFloat scale)
    {
        if (!CGAffineTransformIsIdentity(view.transform))
        {
            view.transform = CGAffineTransformIdentity;
        }
        const CGRect frame = CGRectMake(0, 0, size.width, size.height);
        if (fabs(CGRectGetWidth(view.bounds) - size.width) > 0.5 || fabs(CGRectGetHeight(view.bounds) - size.height) > 0.5
            || fabs(view.frame.origin.x) > 0.5 || fabs(view.frame.origin.y) > 0.5)
        {
            view.frame = frame;
        }
        for (UIView* child in view.subviews)
        {
            if (!child.translatesAutoresizingMaskIntoConstraints)
            {
                continue;
            }
            if (fabs(CGRectGetWidth(child.bounds) - size.width) > 0.5
                || fabs(CGRectGetHeight(child.bounds) - size.height) > 0.5)
            {
                child.frame = view.bounds;
            }
        }
        PinMetalDrawable(view, size, scale);
    }

    void RestoreIosCanvasFrame()
    {
        @autoreleasepool
        {
            UIWindowScene* scene = GetForegroundWindowScene();
            if (scene == nil)
            {
                return;
            }

            const CGRect bounds = scene.effectiveGeometry.coordinateSpace.bounds;
            if (bounds.size.width < 1 || bounds.size.height < 1)
            {
                return;
            }

            const CGFloat scale = scene.traitCollection.displayScale;
            for (UIWindow* window in scene.windows)
            {
                if (window.hidden || window.rootViewController == nil)
                {
                    continue;
                }
                UIView* root = window.rootViewController.view;
                if (root == nil || !ViewTreeHasMetalLayer(root))
                {
                    continue;
                }
                PinViewToSize(root, bounds.size, scale);
                [root layoutIfNeeded];
            }
        }
    }

    IosSafeArea GetIosSafeArea()
    {
        IosSafeArea result{};
        @autoreleasepool
        {
            UIWindowScene* scene = GetForegroundWindowScene();
            if (scene == nil)
            {
                return result;
            }

            // Scene geometry stays landscape when a SwiftUI Menu becomes the
            // key window. SDL_GetWindowSize and keyWindow.bounds follow the menu.
            const CGSize sceneSize = scene.effectiveGeometry.coordinateSpace.bounds.size;
            result.windowWidth = static_cast<int32_t>(std::lround(sceneSize.width));
            result.windowHeight = static_cast<int32_t>(std::lround(sceneSize.height));
            result.scale = static_cast<float>(scene.traitCollection.displayScale);

            const BOOL landscape = sceneSize.width >= sceneSize.height;
            UIWindow* window = nil;
            CGFloat bestArea = 0;
            auto considerWindow = [&](UIWindow* candidate, BOOL requireOrientationMatch) {
                if (candidate.hidden || candidate.rootViewController == nil)
                {
                    return;
                }
                if (!ViewTreeHasMetalLayer(candidate.rootViewController.view))
                {
                    return;
                }
                const CGFloat width = CGRectGetWidth(candidate.bounds);
                const CGFloat height = CGRectGetHeight(candidate.bounds);
                const BOOL matches = landscape ? (width >= height) : (height >= width);
                if (requireOrientationMatch && !matches)
                {
                    return;
                }
                const CGFloat area = width * height;
                if (area > bestArea)
                {
                    bestArea = area;
                    window = candidate;
                }
            };
            for (UIWindow* candidate in scene.windows)
            {
                considerWindow(candidate, YES);
            }
            if (window == nil)
            {
                bestArea = 0;
                for (UIWindow* candidate in scene.windows)
                {
                    considerWindow(candidate, NO);
                }
            }
            if (window != nil)
            {
                const UIEdgeInsets insets = window.safeAreaInsets;
                result.top = static_cast<float>(insets.top);
                result.left = static_cast<float>(insets.left);
                result.bottom = static_cast<float>(insets.bottom);
                result.right = static_cast<float>(insets.right);
            }
        }
        return result;
    }

    static UIViewController* GetHostViewController()
    {
        UIViewController* fallback = nil;
        CGFloat bestArea = 0;
        for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
        {
            if (![scene isKindOfClass:UIWindowScene.class])
            {
                continue;
            }

            for (UIWindow* window in static_cast<UIWindowScene*>(scene).windows)
            {
                if (window.hidden || window.rootViewController == nil)
                {
                    continue;
                }

                const CGFloat area = CGRectGetWidth(window.bounds) * CGRectGetHeight(window.bounds);
                if (area > bestArea)
                {
                    bestArea = area;
                    fallback = window.rootViewController;
                }
            }
        }
        return fallback;
    }

} // namespace OpenRCT2::Ui

@interface OpenRCT2TouchTextField : UITextField <UITextFieldDelegate>
@end

@implementation OpenRCT2TouchTextField

    - (instancetype)init
    {
        self = [super initWithFrame:CGRectMake(0, 0, 1, 1)];
        if (self != nil)
        {
            self.delegate = self;
            self.alpha = 0.01;
            self.textColor = UIColor.clearColor;
            self.tintColor = UIColor.clearColor;
            self.backgroundColor = UIColor.clearColor;
            self.keyboardAppearance = UIKeyboardAppearanceLight;
            self.autocorrectionType = UITextAutocorrectionTypeNo;
            self.spellCheckingType = UITextSpellCheckingTypeNo;
            self.smartDashesType = UITextSmartDashesTypeNo;
            self.smartQuotesType = UITextSmartQuotesTypeNo;
            self.accessibilityElementsHidden = YES;
            self.text = @" ";
        }
        return self;
    }

    - (BOOL)textField:(UITextField*)textField
        shouldChangeCharactersInRange:(NSRange)range
                    replacementString:(NSString*)replacement
    {
        if (replacement.length == 0)
        {
            OpenRCT2::Ui::PushKey(SDLK_BACKSPACE, SDL_SCANCODE_BACKSPACE);
        }
        else
        {
            OpenRCT2::Ui::PushTextInput(replacement);
        }
        return NO;
    }

    - (BOOL)textFieldShouldReturn:(UITextField*)textField
    {
        OpenRCT2::Ui::PushKey(SDLK_RETURN, SDL_SCANCODE_RETURN);
        return NO;
    }

@end

namespace OpenRCT2::Ui
{
    class iOSContext final : public IPlatformUiContext
    {
    private:
        OpenRCT2TouchTextField* _textField = nil;

        void EnsureTextField()
        {
            if (_textField != nil)
            {
                return;
            }

            UIViewController* host = GetHostViewController();
            if (host == nil)
            {
                return;
            }

            _textField = [[OpenRCT2TouchTextField alloc] init];
            [host.view addSubview:_textField];
        }

    public:
        iOSContext()
        {
            // Intersection with Info.plist: iPhone drops upside-down; iPad keeps all four.
            SDL_SetHint(SDL_HINT_ORIENTATIONS, "Portrait LandscapeLeft LandscapeRight PortraitUpsideDown");
            // Behave like a regular app: keep the Home indicator visible and let
            // system edge gestures win on their first swipe.
            SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "0");
            SDL_SetHint(SDL_HINT_ENABLE_SCREEN_KEYBOARD, "1");
        }

        ~iOSContext() override
        {
            EndTextInput();
            NativeChromeDetach();
            [_textField removeFromSuperview];
            [_textField release];
            _textField = nil;
        }

        void SetWindowIcon([[maybe_unused]] SDL_Window* window) override
        {
        }

        void AttachNativeOverlay(SDL_Window* window) override
        {
            NativeChromeAttach(window);
        }

        bool HandleSdlEvent(const SDL_Event& event) override
        {
            return NativeChromeHandleEvent(event);
        }

        void TickNativeOverlay() override
        {
            NativeChromeTick();
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
            SDL_Window* window, const std::string& title) override
        {
            return ShowRCT2DirectoryImporter(window, title);
        }

        bool HasFilePicker() const override
        {
            return true;
        }

        void BeginTextInput() override
        {
            @autoreleasepool
            {
                EnsureTextField();
                _textField.text = @" ";
                const bool becameFirstResponder = _textField != nil && [_textField becomeFirstResponder];
                LOG_INFO("[OpenRCT2Touch] native text input first_responder=%d", becameFirstResponder);
            }
        }

        void EndTextInput() override
        {
            @autoreleasepool
            {
                [_textField resignFirstResponder];
            }
        }
    };

    std::unique_ptr<IPlatformUiContext> CreatePlatformUiContext()
    {
        return std::make_unique<iOSContext>();
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
