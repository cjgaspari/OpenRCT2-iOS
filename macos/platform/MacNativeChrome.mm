/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "MacNativeChrome.h"

#if defined(__APPLE__) && defined(__MACH__) && TARGET_OS_OSX

    #include "MacCocoaWindow.h"

    #include <SDL.h>
    #include <openrct2/Diagnostic.h>

    #import <AppKit/AppKit.h>
    #import <Foundation/Foundation.h>

extern "C" {
void* OpenRCT2MacChromeAttach(void* contentView, void (*onAction)(int32_t, int32_t));
void OpenRCT2MacChromeDetach(void* session);
void OpenRCT2MacChromeBringToFront(void* session);
}

namespace OpenRCT2::Ui
{
    namespace
    {
        void* gMacChromeSession = nullptr;

        void MacChromeOnAction(int32_t code, int32_t extra)
        {
            LOG_INFO("Mac Liquid Glass chrome action code=%d extra=%d", code, extra);
            (void)extra;
            (void)code;
        }
    } // namespace

    void MacNativeChromeAttach(SDL_Window* window)
    {
        @autoreleasepool
        {
            MacNativeChromeDetach();

            NSWindow* nsWindow = MacCocoaWindowFromSdl(window);
            if (nsWindow == nil)
            {
                LOG_WARNING("MacNativeChromeAttach: could not resolve NSWindow from SDL");
                return;
            }

            NSView* contentView = nsWindow.contentView;
            if (contentView == nil)
            {
                LOG_WARNING("MacNativeChromeAttach: NSWindow has no contentView");
                return;
            }

            // Ensure the content view can host translucent overlay subviews.
            if (!contentView.wantsLayer)
            {
                contentView.wantsLayer = YES;
            }

            // MRC build (-fno-objc-arc): NSView* → void* without __bridge.
            void* contentViewPtr = static_cast<void*>(contentView);
            // Set OPENRCT2_MAC_GLASS=0 to capture classic engine chrome screenshots.
            const char* glassEnv = getenv("OPENRCT2_MAC_GLASS");
            if (glassEnv != nullptr && (glassEnv[0] == '0') && (glassEnv[1] == '\0'))
            {
                LOG_INFO("Mac Liquid Glass chrome skipped (OPENRCT2_MAC_GLASS=0)");
                return;
            }

            gMacChromeSession = OpenRCT2MacChromeAttach(contentViewPtr, &MacChromeOnAction);
            if (gMacChromeSession == nullptr)
            {
                LOG_WARNING("MacNativeChromeAttach: Swift chrome attach failed");
                return;
            }

            LOG_INFO("Mac Liquid Glass chrome attached to Cocoa contentView");
        }
    }

    void MacNativeChromeDetach()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
            {
                return;
            }
            OpenRCT2MacChromeDetach(gMacChromeSession);
            gMacChromeSession = nullptr;
        }
    }

    void MacNativeChromeTick()
    {
        @autoreleasepool
        {
            if (gMacChromeSession == nullptr)
            {
                return;
            }
            OpenRCT2MacChromeBringToFront(gMacChromeSession);
        }
    }

    bool MacNativeChromeHandleEvent([[maybe_unused]] const SDL_Event& event)
    {
        // Pass-through overlay owns hit testing in AppKit; SDL keeps park input.
        return false;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_OSX
