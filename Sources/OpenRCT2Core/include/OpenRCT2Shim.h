#ifndef OPENRCT2_SHIM_H
#define OPENRCT2_SHIM_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Game resolution
#define ORCT2_SCREEN_WIDTH 1280
#define ORCT2_SCREEN_HEIGHT 720

/// Initialize OpenRCT2 context and rendering engine
/// @param configPath Optional path to config directory (NULL for default)
/// @return true if initialization succeeded
bool openrct2_init(const char* configPath);

/// Shutdown OpenRCT2 and release resources
void openrct2_shutdown(void);

/// Advance game state by one tick (~25ms)
void openrct2_tick(void);

/// Get pointer to 8-bit indexed color frame buffer
/// @return Pointer to pixel data (size: ORCT2_SCREEN_WIDTH * ORCT2_SCREEN_HEIGHT bytes)
const uint8_t* openrct2_get_frame_buffer(void);

/// Get pointer to color palette (BGRA format)
/// @return Pointer to palette data (size: 256 * 4 bytes for BGRA uint32_t entries)
/// @note Returns as uint8_t* for C compatibility; cast to uint32_t* for use
const uint8_t* openrct2_get_palette(void);

/// Get pitch (stride) of frame buffer in bytes
/// @return Bytes per row in frame buffer (may be >= width for alignment)
int32_t openrct2_get_pitch(void);

/// Set screen resolution (for window resize handling)
/// @param width New width in pixels
/// @param height New height in pixels
/// @return true if resize succeeded
bool openrct2_set_screen_size(int32_t width, int32_t height);

/// Get current frame buffer width
/// @return Width in pixels
uint32_t openrct2_get_frame_width(void);

/// Get current frame buffer height
/// @return Height in pixels
uint32_t openrct2_get_frame_height(void);

#ifdef __cplusplus
}
#endif

#endif // OPENRCT2_SHIM_H
