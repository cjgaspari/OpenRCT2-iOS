// OpenRCT2.h - Public C API for OpenRCT2 game engine
// This header bridges the C++ OpenRCT2 core to Swift

#ifndef OPENRCT2_H
#define OPENRCT2_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Game dimensions (from original RCT2)
#define ORCT2_SCREEN_WIDTH 640
#define ORCT2_SCREEN_HEIGHT 480

// Lifecycle functions
bool openrct2_init(const char* dataPath);
void openrct2_shutdown(void);

// Per-frame update
void openrct2_tick(void);

// Frame buffer access (8-bit paletted)
const uint8_t* openrct2_get_frame_buffer(void);
size_t openrct2_get_frame_buffer_size(void);
uint32_t openrct2_get_frame_width(void);
uint32_t openrct2_get_frame_height(void);

// Palette access (256 entries, RGB format)
const uint8_t* openrct2_get_palette(void);

// Touch/input events (for future use)
void openrct2_touch_down(float x, float y);
void openrct2_touch_moved(float x, float y);
void openrct2_touch_up(float x, float y);

#ifdef __cplusplus
}
#endif

#endif // OPENRCT2_H
