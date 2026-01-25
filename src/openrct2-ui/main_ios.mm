/**
 * iOS main entry point for OpenRCT2
 * This is required because SDL2 on iOS needs UIApplicationMain to be called
 * with SDL's UIKit delegate to properly handle the iOS app lifecycle.
 */

#import <UIKit/UIKit.h>

// We need to handle main ourselves - tell SDL not to redefine it
#define SDL_MAIN_HANDLED
#import <SDL2/SDL.h>

// Forward declaration of SDL_main which is defined in Ui.cpp
extern "C" int SDL_main(int argc, char* argv[]);

int main(int argc, char* argv[])
{
    @autoreleasepool
    {
        // SDL_SetMainReady must be called when using SDL_MAIN_HANDLED
        SDL_SetMainReady();

        // Let SDL start the iOS UIKit app lifecycle, which will call SDL_main
        return SDL_UIKitRunApp(argc, argv, SDL_main);
    }
}
