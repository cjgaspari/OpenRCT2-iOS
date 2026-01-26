import Foundation

/// C ABI declarations for the OpenRCT2 visionOS bridge.
@_silgen_name("openrct2_set_paths")
func openrct2_set_paths(
    _ bundlePath: UnsafePointer<CChar>?,
    _ userPath: UnsafePointer<CChar>?,
    _ cachePath: UnsafePointer<CChar>?
)

@_silgen_name("openrct2_init")
func openrct2_init(_ configPath: UnsafeRawPointer?) -> Bool

@_silgen_name("openrct2_init_full")
func openrct2_init_full() -> Bool

@_silgen_name("openrct2_get_init_error")
func openrct2_get_init_error() -> UnsafePointer<CChar>?

@_silgen_name("openrct2_shutdown")
func openrct2_shutdown()

@_silgen_name("openrct2_tick")
func openrct2_tick()

@_silgen_name("openrct2_get_frame_buffer")
func openrct2_get_frame_buffer() -> UnsafeRawPointer?

@_silgen_name("openrct2_get_palette")
func openrct2_get_palette() -> UnsafeRawPointer?

@_silgen_name("openrct2_get_pitch")
func openrct2_get_pitch() -> Int32

@_silgen_name("openrct2_set_screen_size")
func openrct2_set_screen_size(_ width: Int32, _ height: Int32) -> Bool

@_silgen_name("openrct2_get_frame_width")
func openrct2_get_frame_width() -> UInt32

@_silgen_name("openrct2_get_frame_height")
func openrct2_get_frame_height() -> UInt32

@_silgen_name("openrct2_is_fully_initialized")
func openrct2_is_fully_initialized() -> Bool
