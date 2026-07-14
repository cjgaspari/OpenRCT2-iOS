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

    #include "RCT2Importer.iOS.h"

    #include <openrct2-ui/UiContext.h>

    #include <SDL.h>
    #include <UIKit/UIKit.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/ui/UiContext.h>

namespace OpenRCT2::Ui
{
    static void PushTextInput(NSString* text)
    {
        const char* utf8 = text.UTF8String;
        if (utf8 == nullptr || utf8[0] == '\0')
        {
            return;
        }

        SDL_Event event{};
        event.type = SDL_TEXTINPUT;
        SDL_strlcpy(event.text.text, utf8, sizeof(event.text.text));
        SDL_PushEvent(&event);
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

    static UIViewController* GetHostViewController()
    {
        UIViewController* fallback = nil;
        for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
        {
            if (![scene isKindOfClass:UIWindowScene.class])
            {
                continue;
            }

            for (UIWindow* window in static_cast<UIWindowScene*>(scene).windows)
            {
                if (window.rootViewController == nil)
                {
                    continue;
                }

                fallback = window.rootViewController;
                if (window.isKeyWindow)
                {
                    return window.rootViewController;
                }
            }
        }
        return fallback;
    }

    class iOSContext final : public IPlatformUiContext
    {
    private:
        id _keyboardShowObserver = nil;
        id _keyboardHideObserver = nil;
        UIView* _touchKeyboardView = nil;
        bool _systemKeyboardVisible = false;
        bool _textInputActive = false;
        bool _uppercase = false;
        uint64_t _textInputGeneration = 0;

        UIButton* MakeButton(NSString* title, void (^handler)(UIAction*))
        {
            UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            button.backgroundColor = UIColor.tertiarySystemBackgroundColor;
            button.layer.cornerRadius = 7.0;
            button.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium];
            [button setTitle:title forState:UIControlStateNormal];
            [button.heightAnchor constraintEqualToConstant:44.0].active = YES;
            [button addAction:[UIAction actionWithHandler:handler] forControlEvents:UIControlEventTouchUpInside];
            return button;
        }

        UIStackView* MakeCharacterRow(NSString* characters, bool letters)
        {
            UIStackView* row = [[[UIStackView alloc] init] autorelease];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 5.0;
            row.distribution = UIStackViewDistributionFillEqually;

            for (NSUInteger index = 0; index < characters.length; index++)
            {
                NSString* character = [characters substringWithRange:NSMakeRange(index, 1)];
                UIButton* button = MakeButton(character.uppercaseString, ^([[maybe_unused]] UIAction* action) {
                    NSString* output = letters && !_uppercase ? character.lowercaseString : character.uppercaseString;
                    PushTextInput(output);
                });
                [row addArrangedSubview:button];
            }
            return row;
        }

        void HideTouchKeyboard()
        {
            if (_touchKeyboardView != nil)
            {
                [_touchKeyboardView removeFromSuperview];
                _touchKeyboardView = nil;
            }
        }

        void ShowTouchKeyboard()
        {
            if (_touchKeyboardView != nil || !_textInputActive)
            {
                return;
            }

            UIViewController* host = GetHostViewController();
            if (host == nil)
            {
                return;
            }

            UIView* panel = [[[UIView alloc] init] autorelease];
            panel.translatesAutoresizingMaskIntoConstraints = NO;
            panel.backgroundColor = UIColor.secondarySystemBackgroundColor;
            panel.layer.cornerRadius = 12.0;
            panel.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;

            UIStackView* keyboard = [[[UIStackView alloc] init] autorelease];
            keyboard.translatesAutoresizingMaskIntoConstraints = NO;
            keyboard.axis = UILayoutConstraintAxisVertical;
            keyboard.spacing = 6.0;

            UIStackView* header = [[[UIStackView alloc] init] autorelease];
            header.axis = UILayoutConstraintAxisHorizontal;
            header.alignment = UIStackViewAlignmentCenter;

            UILabel* title = [[[UILabel alloc] init] autorelease];
            title.text = @"Touch keyboard";
            title.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
            [header addArrangedSubview:title];

            UIButton* close = MakeButton(@"Hide", ^([[maybe_unused]] UIAction* action) {
                HideTouchKeyboard();
            });
            [close.widthAnchor constraintEqualToConstant:72.0].active = YES;
            [header addArrangedSubview:close];
            [keyboard addArrangedSubview:header];

            [keyboard addArrangedSubview:MakeCharacterRow(@"1234567890", false)];
            [keyboard addArrangedSubview:MakeCharacterRow(@"QWERTYUIOP", true)];
            [keyboard addArrangedSubview:MakeCharacterRow(@"ASDFGHJKL", true)];

            UIStackView* bottomLetters = [[[UIStackView alloc] init] autorelease];
            bottomLetters.axis = UILayoutConstraintAxisHorizontal;
            bottomLetters.spacing = 5.0;
            bottomLetters.distribution = UIStackViewDistributionFillEqually;

            UIButton* shift = MakeButton(@"⇧", ^(UIAction* action) {
                _uppercase = !_uppercase;
                static_cast<UIButton*>(action.sender).selected = _uppercase;
                static_cast<UIButton*>(action.sender).backgroundColor
                    = _uppercase ? UIColor.systemBlueColor : UIColor.tertiarySystemBackgroundColor;
            });
            [bottomLetters addArrangedSubview:shift];
            for (NSUInteger index = 0; index < @"ZXCVBNM".length; index++)
            {
                NSString* character = [@"ZXCVBNM" substringWithRange:NSMakeRange(index, 1)];
                [bottomLetters addArrangedSubview:MakeButton(character, ^([[maybe_unused]] UIAction* action) {
                    PushTextInput(_uppercase ? character.uppercaseString : character.lowercaseString);
                })];
            }
            [bottomLetters addArrangedSubview:MakeButton(@"⌫", ^([[maybe_unused]] UIAction* action) {
                PushKey(SDLK_BACKSPACE, SDL_SCANCODE_BACKSPACE);
            })];
            [keyboard addArrangedSubview:bottomLetters];

            UIStackView* controls = [[[UIStackView alloc] init] autorelease];
            controls.axis = UILayoutConstraintAxisHorizontal;
            controls.spacing = 5.0;
            controls.distribution = UIStackViewDistributionFillEqually;
            [controls addArrangedSubview:MakeButton(@"Cancel", ^([[maybe_unused]] UIAction* action) {
                PushKey(SDLK_ESCAPE, SDL_SCANCODE_ESCAPE);
            })];
            [controls addArrangedSubview:MakeButton(@"-", ^([[maybe_unused]] UIAction* action) {
                PushTextInput(@"-");
            })];
            [controls addArrangedSubview:MakeButton(@"_", ^([[maybe_unused]] UIAction* action) {
                PushTextInput(@"_");
            })];
            [controls addArrangedSubview:MakeButton(@"Space", ^([[maybe_unused]] UIAction* action) {
                PushTextInput(@" ");
            })];
            [controls addArrangedSubview:MakeButton(@"Done", ^([[maybe_unused]] UIAction* action) {
                PushKey(SDLK_RETURN, SDL_SCANCODE_RETURN);
            })];
            [keyboard addArrangedSubview:controls];

            [panel addSubview:keyboard];
            [host.view addSubview:panel];
            [NSLayoutConstraint activateConstraints:@[
                [panel.leadingAnchor constraintEqualToAnchor:host.view.leadingAnchor],
                [panel.trailingAnchor constraintEqualToAnchor:host.view.trailingAnchor],
                [panel.bottomAnchor constraintEqualToAnchor:host.view.bottomAnchor],
                [keyboard.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:12.0],
                [keyboard.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12.0],
                [keyboard.topAnchor constraintEqualToAnchor:panel.topAnchor constant:8.0],
                [keyboard.bottomAnchor constraintEqualToAnchor:host.view.safeAreaLayoutGuide.bottomAnchor constant:-8.0],
            ]];
            _touchKeyboardView = panel;
            LOG_INFO("[OpenRCT2Touch] text-input: showing touch keyboard fallback");
        }

    public:
        iOSContext()
        {
            SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
            SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "2");
            SDL_SetHint(SDL_HINT_ENABLE_SCREEN_KEYBOARD, "1");

            NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
            _keyboardShowObserver = [notifications addObserverForName:UIKeyboardWillShowNotification
                                                                object:nil
                                                                 queue:NSOperationQueue.mainQueue
                                                            usingBlock:^(NSNotification* notification) {
                CGRect frame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
                _systemKeyboardVisible = CGRectGetHeight(frame) >= 100.0;
                if (_systemKeyboardVisible)
                {
                    HideTouchKeyboard();
                }
            }];
            _keyboardHideObserver = [notifications addObserverForName:UIKeyboardWillHideNotification
                                                                object:nil
                                                                 queue:NSOperationQueue.mainQueue
                                                            usingBlock:^([[maybe_unused]] NSNotification* notification) {
                _systemKeyboardVisible = false;
            }];
        }

        ~iOSContext() override
        {
            EndTextInput();
            NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
            [notifications removeObserver:_keyboardShowObserver];
            [notifications removeObserver:_keyboardHideObserver];
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
            SDL_Window* window, const std::string& title) override
        {
            return ShowRCT2DirectoryImporter(window, title);
        }

        bool HasFilePicker() const override
        {
            return true;
        }

        void BeginTextInput(bool preferTouchKeyboard) override
        {
            _textInputActive = true;
            const auto generation = ++_textInputGeneration;
            if (!preferTouchKeyboard)
            {
                HideTouchKeyboard();
                return;
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                if (_textInputActive && generation == _textInputGeneration && !_systemKeyboardVisible)
                {
                    ShowTouchKeyboard();
                }
            });
        }

        void EndTextInput() override
        {
            _textInputActive = false;
            ++_textInputGeneration;
            HideTouchKeyboard();
        }
    };

    std::unique_ptr<IPlatformUiContext> CreatePlatformUiContext()
    {
        return std::make_unique<iOSContext>();
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
