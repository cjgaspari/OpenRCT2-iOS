// main.m - SDL2 iOS app entry point
// This is a minimal SDL2 app that proves the rendering pipeline works

#include <SDL2/SDL.h>
#include <stdio.h>

// Screen dimensions
#define SCREEN_WIDTH 640
#define SCREEN_HEIGHT 480

int SDL_main(int argc, char* argv[])
{
    SDL_Window* window = NULL;
    SDL_Renderer* renderer = NULL;

    printf("OpenRCT2 iOS - SDL2 Test\n");

    // Initialize SDL
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0)
    {
        printf("SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }

    printf("SDL initialized successfully\n");

    // Create window
    window = SDL_CreateWindow(
        "OpenRCT2 iOS", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT,
        SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI);

    if (window == NULL)
    {
        printf("Window could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    printf("Window created successfully\n");

    // Create renderer
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    if (renderer == NULL)
    {
        printf("Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    printf("Renderer created successfully\n");
    printf("Starting main loop...\n");

    // Main loop
    int running = 1;
    int frame = 0;
    SDL_Event event;

    while (running)
    {
        // Handle events
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_QUIT)
            {
                running = 0;
            }
            if (event.type == SDL_FINGERDOWN)
            {
                // Touch event - cycle colors on tap
                frame += 60;
            }
        }

        // Animate background color
        int r = (frame % 256);
        int g = ((frame * 2) % 256);
        int b = ((frame * 3) % 256);

        // Clear screen with animated color
        SDL_SetRenderDrawColor(renderer, r, g, b, 255);
        SDL_RenderClear(renderer);

        // Draw a white rectangle (placeholder for OpenRCT2 content)
        SDL_Rect rect = { 50, 50, SCREEN_WIDTH - 100, SCREEN_HEIGHT - 100 };
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
        SDL_RenderFillRect(renderer, &rect);

        // Draw diagonal stripes pattern (represents paletted graphics)
        for (int i = 0; i < 10; i++)
        {
            int offset = (frame + i * 30) % SCREEN_WIDTH;
            SDL_SetRenderDrawColor(renderer, (i * 25) % 256, 100, 150, 255);
            SDL_RenderDrawLine(renderer, offset, 50, 50, 50 + offset / 2);
        }

        // Draw "OpenRCT2" text area (green box placeholder)
        SDL_Rect textRect = { 100, 100, 200, 50 };
        SDL_SetRenderDrawColor(renderer, 76, 140, 32, 255); // OpenRCT2 grass green
        SDL_RenderFillRect(renderer, &textRect);

        // Draw bouncing ball (animation test)
        int ballX = SCREEN_WIDTH / 2 + (int)(100 * SDL_sin(frame * 0.05));
        int ballY = SCREEN_HEIGHT / 2 + (int)(100 * SDL_cos(frame * 0.03));
        SDL_Rect ball = { ballX - 25, ballY - 25, 50, 50 };
        SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        SDL_RenderFillRect(renderer, &ball);

        // Present
        SDL_RenderPresent(renderer);

        frame++;
    }

    // Cleanup
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
