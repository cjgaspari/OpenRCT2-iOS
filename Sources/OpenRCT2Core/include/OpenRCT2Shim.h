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

/// Get pointer to color palette (RGB format)
/// @return Pointer to palette data (size: 256 * 3 bytes for RGB entries)
const uint8_t* openrct2_get_palette(void);

#ifdef __cplusplus
}
#endif

#endif // OPENRCT2_SHIM_H
