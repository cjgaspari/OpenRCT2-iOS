#include <metal_stdlib>
using namespace metal;

/// Represents a single color palette entry in BGRA format
struct PaletteEntry {
    uint8_t blue;
    uint8_t green;
    uint8_t red;
    uint8_t alpha;
};

/// Converts indexed 8-bit pixels to RGBA 32-bit using a BGRA palette
/// Handles channel reordering and alpha preservation
///
/// Buffer Layout:
/// - buffer(0): uint8_t* indexedBuffer (1280×720 = 921,600 bytes)
/// - buffer(1): PaletteEntry* palette (256 entries × 4 bytes = 1,024 bytes)
/// - texture(0): Output BGRA8Unorm texture (write-only)
///
/// Thread Organization:
/// - Each thread processes one pixel
/// - Grid covers entire texture with 16×16 threadgroups
kernel void convertIndexedToRGBA(
    device const uint8_t* indexedBuffer [[buffer(0)]],
    device const uint32_t* paletteBuffer [[buffer(1)]],
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Validate bounds
    uint width = outTexture.get_width();
    uint height = outTexture.get_height();
    
    if (gid.x >= width || gid.y >= height) {
        return;
    }
    
    // Calculate linear index into indexed buffer
    // Note: Pitch is assumed to equal width for now
    // If X8DrawingEngine uses different pitch, this must be updated
    uint linearIndex = gid.y * width + gid.x;
    
    // Read indexed color (8-bit palette index)
    uint8_t paletteIndex = indexedBuffer[linearIndex];
    
    // Read BGRA palette entry (stored as uint32_t for efficiency)
    uint32_t bgraValue = paletteBuffer[paletteIndex];
    
    // Extract BGRA components from packed uint32_t
    // Metal stores uint32_t in little-endian, so:
    // Byte 0 = B, Byte 1 = G, Byte 2 = R, Byte 3 = A
    uint8_t b = (bgraValue >> 0) & 0xFF;
    uint8_t g = (bgraValue >> 8) & 0xFF;
    uint8_t r = (bgraValue >> 16) & 0xFF;
    uint8_t a = (bgraValue >> 24) & 0xFF;
    
    // Convert to RGBA for output texture
    // Metal's write() always expects RGBA component order regardless of pixel format
    // The texture format (bgra8Unorm) handles byte swapping internally
    half4 rgba = half4(half(r) / 255.0, half(g) / 255.0, half(b) / 255.0, half(a) / 255.0);
    
    // Write to output texture
    outTexture.write(rgba, gid);
}

/// Alternative kernel for debugging: pass-through test pattern
/// Useful for validating texture and command buffer setup
/// Outputs a checkerboard pattern
kernel void testPattern(
    texture2d<half, access::write> outTexture [[texture(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint pattern = ((gid.x >> 4) + (gid.y >> 4)) & 1;
    
    if (pattern == 0) {
        outTexture.write(half4(1, 1, 1, 1), gid);  // White
    } else {
        outTexture.write(half4(0, 0, 0, 1), gid);  // Black
    }
}
