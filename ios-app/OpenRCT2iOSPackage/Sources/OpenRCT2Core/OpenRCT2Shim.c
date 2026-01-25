// OpenRCT2Shim.c - Stub implementation for PoC
// This is a placeholder that will be replaced with actual C++ bridge code

#include "include/OpenRCT2.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Static buffers for the PoC
static uint8_t g_frameBuffer[ORCT2_SCREEN_WIDTH * ORCT2_SCREEN_HEIGHT];
static uint8_t g_palette[256 * 3]; // RGB palette
static bool g_initialized = false;
static uint32_t g_tickCount = 0;

// Initialize with a test pattern and palette
bool openrct2_init(const char* dataPath) {
    if (g_initialized) return true;
    
    // Initialize a colorful palette (simple gradient for testing)
    for (int i = 0; i < 256; i++) {
        // Create a rainbow-ish palette
        g_palette[i * 3 + 0] = (uint8_t)((i * 4) % 256);       // R
        g_palette[i * 3 + 1] = (uint8_t)((i * 2 + 85) % 256);  // G
        g_palette[i * 3 + 2] = (uint8_t)((255 - i) % 256);     // B
    }
    
    // Some specific colors for visual interest
    // Black
    g_palette[0] = 0; g_palette[1] = 0; g_palette[2] = 0;
    // White
    g_palette[3] = 255; g_palette[4] = 255; g_palette[5] = 255;
    // RCT2 grass green
    g_palette[6] = 76; g_palette[7] = 140; g_palette[8] = 32;
    // RCT2 path brown
    g_palette[9] = 139; g_palette[10] = 90; g_palette[11] = 43;
    // Sky blue
    g_palette[12] = 135; g_palette[13] = 206; g_palette[14] = 235;
    
    // Clear frame buffer
    memset(g_frameBuffer, 0, sizeof(g_frameBuffer));
    
    g_initialized = true;
    return true;
}

void openrct2_shutdown(void) {
    g_initialized = false;
    g_tickCount = 0;
}

void openrct2_tick(void) {
    if (!g_initialized) return;
    
    g_tickCount++;
    
    // Generate an animated test pattern to prove rendering works
    // This creates moving diagonal stripes with some animated elements
    
    float time = (float)g_tickCount * 0.05f;
    
    for (uint32_t y = 0; y < ORCT2_SCREEN_HEIGHT; y++) {
        for (uint32_t x = 0; x < ORCT2_SCREEN_WIDTH; x++) {
            // Create animated diagonal stripes
            float fx = (float)x;
            float fy = (float)y;
            
            // Base pattern: diagonal stripes that scroll
            int pattern = (int)(fx + fy + time * 20.0f) % 256;
            
            // Add some circular ripples from center
            float cx = fx - ORCT2_SCREEN_WIDTH / 2.0f;
            float cy = fy - ORCT2_SCREEN_HEIGHT / 2.0f;
            float dist = sqrtf(cx * cx + cy * cy);
            int ripple = (int)(dist * 0.5f - time * 30.0f) % 64;
            if (ripple < 0) ripple = -ripple;
            
            // Mix patterns
            int color = (pattern + ripple) % 256;
            
            // Add a bouncing rectangle to show animation clearly
            int rectX = (int)(ORCT2_SCREEN_WIDTH / 2.0f + sinf(time) * 200.0f);
            int rectY = (int)(ORCT2_SCREEN_HEIGHT / 2.0f + cosf(time * 0.7f) * 150.0f);
            int rectSize = 60;
            
            if (x >= rectX - rectSize && x < rectX + rectSize &&
                y >= rectY - rectSize && y < rectY + rectSize) {
                // Inside bouncing rectangle - use bright color
                color = 1; // White
            }
            
            g_frameBuffer[y * ORCT2_SCREEN_WIDTH + x] = (uint8_t)color;
        }
    }
    
    // Draw "OpenRCT2 iOS" text area (simple rectangle as placeholder)
    int textY = 20;
    int textX = 20;
    int textW = 200;
    int textH = 40;
    for (int y = textY; y < textY + textH && y < ORCT2_SCREEN_HEIGHT; y++) {
        for (int x = textX; x < textX + textW && x < ORCT2_SCREEN_WIDTH; x++) {
            // Dark background for text area
            g_frameBuffer[y * ORCT2_SCREEN_WIDTH + x] = 0;
        }
    }
}

const uint8_t* openrct2_get_frame_buffer(void) {
    return g_frameBuffer;
}

size_t openrct2_get_frame_buffer_size(void) {
    return ORCT2_SCREEN_WIDTH * ORCT2_SCREEN_HEIGHT;
}

uint32_t openrct2_get_frame_width(void) {
    return ORCT2_SCREEN_WIDTH;
}

uint32_t openrct2_get_frame_height(void) {
    return ORCT2_SCREEN_HEIGHT;
}

const uint8_t* openrct2_get_palette(void) {
    return g_palette;
}

void openrct2_touch_down(float x, float y) {
    // TODO: Forward to OpenRCT2 input system
    (void)x; (void)y;
}

void openrct2_touch_moved(float x, float y) {
    // TODO: Forward to OpenRCT2 input system
    (void)x; (void)y;
}

void openrct2_touch_up(float x, float y) {
    // TODO: Forward to OpenRCT2 input system
    (void)x; (void)y;
}
