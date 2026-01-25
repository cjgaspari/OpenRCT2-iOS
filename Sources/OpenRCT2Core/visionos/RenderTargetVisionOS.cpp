/****************************************************************************
 * RenderTarget - visionOS compatible copy
 * Original: src/openrct2/drawing/RenderTarget.cpp
 ****************************************************************************/

// Force include limits headers early for visionOS SDK compatibility
#include <climits>
#include <cstdint>
#include <limits.h>
#include <openrct2/drawing/RenderTarget.h>

namespace OpenRCT2::Drawing
{
    uint8_t* RenderTarget::GetBitsOffset(const ScreenCoordsXY& pos) const
    {
        return bits + pos.x + pos.y * LineStride();
    }

    RenderTarget RenderTarget::Crop(const ScreenCoordsXY& pos, const ScreenSize& size) const
    {
        RenderTarget result = *this;
        result.bits = GetBitsOffset(pos);
        result.x = pos.x;
        result.y = pos.y;
        result.width = size.width;
        result.height = size.height;
        result.pitch = width + pitch - size.width;
        return result;
    }
} // namespace OpenRCT2::Drawing
