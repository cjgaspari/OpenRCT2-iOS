#ifndef OPENRCT2_SHIM_H
#define OPENRCT2_SHIM_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Game resolution (default values)
#define ORCT2_SCREEN_WIDTH 1280
#define ORCT2_SCREEN_HEIGHT 720

// ============================================================================
// VOS-035: Full GameContext Initialization API
// ============================================================================

/// Initialize OpenRCT2 context with platform environment and UI context.
/// This creates the Context but does NOT load assets yet.
/// @param configPath Optional path to config directory (NULL for default)
/// @return true if initialization succeeded
bool openrct2_init(const char* configPath);

/// Set the base path for game resources (call before openrct2_init).
/// This is needed because the C++ library can't access NSBundle directly.
/// @param bundlePath Path to app bundle resources (e.g., .app/visionos-resources)
/// @param userPath Path to user documents directory
/// @param cachePath Path to caches directory
void openrct2_set_paths(const char* bundlePath, const char* userPath, const char* cachePath);

/// Complete OpenRCT2 initialization - loads g1.dat, g2.dat, initializes repositories.
/// Must be called after openrct2_init() before game can be played.
/// This may take several seconds as it loads all game assets.
/// @return true if full initialization succeeded
bool openrct2_init_full(void);

/// Check if full initialization was performed successfully.
/// @return true if openrct2_init_full() completed successfully
bool openrct2_is_fully_initialized(void);

/// Get initialization error message if initialization failed.
/// @return Error message string, or NULL if no error
const char* openrct2_get_init_error(void);

/// Shutdown OpenRCT2 and release all resources
void openrct2_shutdown(void);

// ============================================================================
// Game Loop API
// ============================================================================

/// Advance game state by one tick (~25ms) and render frame.
/// When fully initialized: runs scene tick and paints to frame buffer.
/// When not fully initialized: skips game logic.
void openrct2_tick(void);

// ============================================================================
// Frame Buffer API
// ============================================================================

/// Get pointer to 8-bit indexed color frame buffer.
/// The buffer is ready for Metal rendering after openrct2_tick() completes.
/// @return Pointer to pixel data (size: width * height bytes), or NULL if not ready
const uint8_t* openrct2_get_frame_buffer(void);

/// Get pointer to color palette (BGRA format).
/// Use this to convert indexed pixels to RGBA for Metal rendering.
/// @return Pointer to palette data (256 entries * 4 bytes = 1024 bytes), or NULL if not ready
/// @note Returns as uint8_t* for C compatibility; cast to uint32_t* for use
const uint8_t* openrct2_get_palette(void);

/// Get pitch (stride) of frame buffer in bytes.
/// @return Bytes per row in frame buffer (may be >= width for alignment)
int32_t openrct2_get_pitch(void);

/// Get current frame buffer width.
/// @return Width in pixels
uint32_t openrct2_get_frame_width(void);

/// Get current frame buffer height.
/// @return Height in pixels
uint32_t openrct2_get_frame_height(void);

// ============================================================================
// Display Control API
// ============================================================================

/// Set screen resolution (for window resize handling).
/// Call this when the visionOS window size changes.
/// @param width New width in pixels
/// @param height New height in pixels
/// @return true if resize succeeded
bool openrct2_set_screen_size(int32_t width, int32_t height);

#ifdef __cplusplus
}
#endif

#endif // OPENRCT2_SHIM_H
