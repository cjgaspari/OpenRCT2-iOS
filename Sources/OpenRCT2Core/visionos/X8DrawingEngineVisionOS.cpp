/****************************************************************************
 * X8DrawingEngineVisionOS - Minimal X8DrawingEngine for visionOS
 *
 * This provides a standalone implementation of X8DrawingEngine that doesn't
 * depend on the full OpenRCT2 codebase. It implements only the functionality
 * needed for the visionOS render pipeline.
 ****************************************************************************/

// Force include limits headers early for visionOS SDK compatibility
#include <climits>
#include <cstdint>
#include <limits.h>

#include <algorithm>
#include <cassert>
#include <cstring>
#include <memory>

#include <openrct2/drawing/X8DrawingEngine.h>

using namespace OpenRCT2;
using namespace OpenRCT2::Drawing;
using namespace OpenRCT2::Ui;

// ============================================================================
// X8WeatherDrawer Implementation
// ============================================================================

X8WeatherDrawer::X8WeatherDrawer()
{
    _weatherPixels = new WeatherPixel[_weatherPixelsCapacity];
}

X8WeatherDrawer::~X8WeatherDrawer()
{
    delete[] _weatherPixels;
}

void X8WeatherDrawer::Draw(
    RenderTarget& rt, int32_t x, int32_t y, int32_t width, int32_t height, int32_t xStart, int32_t yStart,
    const uint8_t* weatherpattern)
{
    const uint8_t* pattern = weatherpattern;
    auto patternXSpace = *pattern++;
    auto patternYSpace = *pattern++;

    uint8_t patternStartXOffset = xStart % patternXSpace;
    uint8_t patternStartYOffset = yStart % patternYSpace;

    uint32_t pixelOffset = rt.LineStride() * y + x;
    uint8_t patternYPos = patternStartYOffset % patternYSpace;

    uint8_t* screenBits = rt.bits;

    WeatherPixel* newPixels = &_weatherPixels[_weatherPixelsCount];
    for (; height != 0; height--)
    {
        auto patternX = pattern[patternYPos * 2];
        if (patternX != 0xFF)
        {
            if (_weatherPixelsCount < (_weatherPixelsCapacity - static_cast<uint32_t>(width)))
            {
                uint32_t finalPixelOffset = width + pixelOffset;
                uint32_t xPixelOffset = pixelOffset;
                xPixelOffset += (static_cast<uint8_t>(patternX - patternStartXOffset)) % patternXSpace;

                auto patternPixel = pattern[patternYPos * 2 + 1];
                for (; xPixelOffset < finalPixelOffset; xPixelOffset += patternXSpace)
                {
                    uint8_t current_pixel = screenBits[xPixelOffset];
                    screenBits[xPixelOffset] = patternPixel;
                    _weatherPixelsCount++;
                    *newPixels++ = { xPixelOffset, current_pixel };
                }
            }
        }
        pixelOffset += rt.LineStride();
        patternYPos++;
        patternYPos %= patternYSpace;
    }
}

void X8WeatherDrawer::Restore(RenderTarget& rt)
{
    if (_weatherPixelsCount > 0)
    {
        uint32_t numPixels = rt.LineStride() * rt.height;
        uint8_t* bits = rt.bits;
        for (uint32_t i = 0; i < _weatherPixelsCount; i++)
        {
            WeatherPixel weatherPixel = _weatherPixels[i];
            if (weatherPixel.Position >= numPixels)
            {
                break;
            }
            bits[weatherPixel.Position] = weatherPixel.Colour;
        }
        _weatherPixelsCount = 0;
    }
}

// ============================================================================
// X8DrawingEngine Implementation
// ============================================================================

X8DrawingEngine::X8DrawingEngine([[maybe_unused]] IUiContext& uiContext)
{
    _drawingContext = new X8DrawingContext(this);
    _mainRT.DrawingEngine = this;
}

X8DrawingEngine::~X8DrawingEngine()
{
    delete _drawingContext;
    delete[] _bits;
}

void X8DrawingEngine::Initialise()
{
}

void X8DrawingEngine::Resize(uint32_t width, uint32_t height)
{
    uint32_t pitch = width;
    ConfigureBits(width, height, pitch);

    _drawingContext->BeginDraw();
    _drawingContext->Clear(_mainRT, PaletteIndex::pi10);
    _drawingContext->EndDraw();
}

void X8DrawingEngine::SetPalette([[maybe_unused]] const GamePalette& palette)
{
    // Pack BGRA palette entries into uint32_t in BGRA byte order
    for (size_t i = 0; i < kGamePaletteSize; ++i)
    {
        const auto& p = palette[i];
        _paletteBGRA[i] = (static_cast<uint32_t>(p.alpha) << 24) | (static_cast<uint32_t>(p.red) << 16)
            | (static_cast<uint32_t>(p.green) << 8) | (static_cast<uint32_t>(p.blue));
    }
}

void X8DrawingEngine::SetVSync([[maybe_unused]] bool vsync)
{
    // Not applicable for visionOS
}

void X8DrawingEngine::Invalidate(int32_t left, int32_t top, int32_t right, int32_t bottom)
{
    _invalidationGrid.invalidate(left, top, right, bottom);
}

void X8DrawingEngine::BeginDraw()
{
    _weatherDrawer.Restore(_mainRT);
    _drawingContext->BeginDraw();
}

void X8DrawingEngine::EndDraw()
{
    _drawingContext->EndDraw();
}

void X8DrawingEngine::PaintWindows()
{
    // Simplified for visionOS - no window management
}

void X8DrawingEngine::PaintWeather()
{
    // Weather drawing not implemented for visionOS yet
}

void X8DrawingEngine::CopyRect(int32_t x, int32_t y, int32_t width, int32_t height, int32_t dx, int32_t dy)
{
    if (dx == 0 && dy == 0)
        return;

    int32_t lmargin = std::min(x - dx, 0);
    int32_t rmargin = std::min(static_cast<int32_t>(_width) - (x - dx + width), 0);
    int32_t tmargin = std::min(y - dy, 0);
    int32_t bmargin = std::min(static_cast<int32_t>(_height) - (y - dy + height), 0);
    x -= lmargin;
    y -= tmargin;
    width += lmargin + rmargin;
    height += tmargin + bmargin;

    int32_t stride = _mainRT.LineStride();
    uint8_t* to = _mainRT.bits + y * stride + x;
    uint8_t* from = _mainRT.bits + (y - dy) * stride + x - dx;

    if (dy > 0)
    {
        to += (height - 1) * stride;
        from += (height - 1) * stride;
        stride = -stride;
    }

    for (int32_t i = 0; i < height; i++)
    {
        memmove(to, from, width);
        to += stride;
        from += stride;
    }
}

std::string X8DrawingEngine::Screenshot()
{
    // Screenshot not implemented for visionOS
    return std::string();
}

IDrawingContext* X8DrawingEngine::GetDrawingContext()
{
    if (!_drawingContext->IsActive())
    {
        // Guard assertion removed for visionOS - just return nullptr
        return nullptr;
    }
    return _drawingContext;
}

DrawingEngineFlags X8DrawingEngine::GetFlags()
{
    return { DrawingEngineFlag::dirtyOptimisations, DrawingEngineFlag::parallelDrawing };
}

void X8DrawingEngine::InvalidateImage([[maybe_unused]] uint32_t image)
{
    // Not applicable for this engine
}

RenderTarget* X8DrawingEngine::getRT()
{
    return &_mainRT;
}

void X8DrawingEngine::ConfigureBits(uint32_t width, uint32_t height, uint32_t pitch)
{
    size_t newBitsSize = pitch * height;
    uint8_t* newBits = new uint8_t[newBitsSize];
    if (_bits == nullptr)
    {
        std::fill_n(newBits, newBitsSize, 0);
    }
    else
    {
        if (_pitch == pitch)
        {
            std::copy_n(_bits, std::min(_bitsSize, newBitsSize), newBits);
        }
        else
        {
            uint8_t* src = _bits;
            uint8_t* dst = newBits;

            uint32_t minWidth = std::min(_width, width);
            uint32_t minHeight = std::min(_height, height);
            for (uint32_t y = 0; y < minHeight; y++)
            {
                std::copy_n(src, minWidth, dst);
                if (pitch - minWidth > 0)
                {
                    std::fill_n(dst + minWidth, pitch - minWidth, 0);
                }
                src += _pitch;
                dst += pitch;
            }
        }
        delete[] _bits;
    }

    _bits = newBits;
    _bitsSize = newBitsSize;
    _width = width;
    _height = height;
    _pitch = pitch;

    RenderTarget* rt = &_mainRT;
    rt->bits = _bits;
    rt->x = 0;
    rt->y = 0;
    rt->width = width;
    rt->height = height;
    rt->pitch = _pitch - width;

    ConfigureDirtyGrid();
}

void X8DrawingEngine::OnDrawDirtyBlock(int32_t, int32_t, int32_t, int32_t)
{
}

void X8DrawingEngine::ConfigureDirtyGrid()
{
    const auto blockWidth = 1u << 7;
    const auto blockHeight = 1u << 7;
    _invalidationGrid.reset(_width, _height, blockWidth, blockHeight);
}

// VisionOS bridge accessors
uint8_t* X8DrawingEngine::GetPixelBuffer()
{
    return _bits;
}

uint32_t X8DrawingEngine::GetBufferWidth() const
{
    return _width;
}

uint32_t X8DrawingEngine::GetBufferHeight() const
{
    return _height;
}

int32_t X8DrawingEngine::GetBufferPitch() const
{
    return _mainRT.LineStride();
}

const uint32_t* X8DrawingEngine::GetPaletteBGRA() const
{
    return _paletteBGRA.data();
}

// ============================================================================
// X8DrawingContext Implementation
// ============================================================================

X8DrawingContext::X8DrawingContext(X8DrawingEngine* engine)
{
    _engine = engine;
}

void X8DrawingContext::BeginDraw()
{
    _isDrawing = true;
}

void X8DrawingContext::EndDraw()
{
    _isDrawing = false;
}

void X8DrawingContext::Clear(RenderTarget& rt, PaletteIndex paletteIndex)
{
    if (!_isDrawing)
        return;

    int32_t w = rt.width;
    int32_t h = rt.height;
    uint8_t* ptr = rt.bits;

    for (int32_t y = 0; y < h; y++)
    {
        std::fill_n(ptr, w, EnumValue(paletteIndex));
        ptr += w + rt.pitch;
    }
}

void X8DrawingContext::FillRect(
    RenderTarget& rt, PaletteIndex paletteIndex, int32_t left, int32_t top, int32_t right, int32_t bottom, bool crossHatch)
{
    if (!_isDrawing)
        return;

    if (left > right)
        return;
    if (top > bottom)
        return;
    if (rt.x > right)
        return;
    if (left >= rt.x + rt.width)
        return;
    if (bottom < rt.y)
        return;
    if (top >= rt.y + rt.height)
        return;

    int32_t startX = left - rt.x;
    if (startX < 0)
    {
        startX = 0;
    }

    int32_t endX = right - rt.x + 1;
    if (endX > rt.width)
    {
        endX = rt.width;
    }

    int32_t startY = top - rt.y;
    if (startY < 0)
    {
        startY = 0;
    }

    int32_t endY = bottom - rt.y + 1;
    if (endY > rt.height)
    {
        endY = rt.height;
    }

    int32_t width = endX - startX;
    int32_t height = endY - startY;

    if (crossHatch)
    {
        // Cross hatching - simplified version
        uint8_t* dst = startY * rt.LineStride() + startX + rt.bits;
        for (int32_t i = 0; i < height; i++)
        {
            for (int32_t j = 0; j < width; j += 2)
            {
                dst[j] = EnumValue(paletteIndex);
            }
            dst += rt.LineStride();
        }
    }
    else
    {
        uint8_t* dst = startY * rt.LineStride() + startX + rt.bits;
        for (int32_t i = 0; i < height; i++)
        {
            std::fill_n(dst, width, EnumValue(paletteIndex));
            dst += rt.LineStride();
        }
    }
}

void X8DrawingContext::FilterRect(
    RenderTarget& rt, FilterPaletteID palette, int32_t left, int32_t top, int32_t right, int32_t bottom)
{
    // FilterRect not fully implemented for visionOS - stub
    (void)rt;
    (void)palette;
    (void)left;
    (void)top;
    (void)right;
    (void)bottom;
}

void X8DrawingContext::DrawLine(RenderTarget& rt, PaletteIndex colour, const ScreenLine& line)
{
    // DrawLine not fully implemented for visionOS - stub
    (void)rt;
    (void)colour;
    (void)line;
}

void X8DrawingContext::DrawSprite(RenderTarget& rt, const ImageId imageId, int32_t x, int32_t y)
{
    // DrawSprite not fully implemented for visionOS - stub
    (void)rt;
    (void)imageId;
    (void)x;
    (void)y;
}

void X8DrawingContext::DrawSpriteRawMasked(
    RenderTarget& rt, int32_t x, int32_t y, const ImageId maskImage, const ImageId colourImage)
{
    // DrawSpriteRawMasked not fully implemented for visionOS - stub
    (void)rt;
    (void)x;
    (void)y;
    (void)maskImage;
    (void)colourImage;
}

void X8DrawingContext::DrawSpriteSolid(RenderTarget& rt, const ImageId image, int32_t x, int32_t y, PaletteIndex colour)
{
    // DrawSpriteSolid not fully implemented for visionOS - stub
    (void)rt;
    (void)image;
    (void)x;
    (void)y;
    (void)colour;
}

void X8DrawingContext::DrawGlyph(RenderTarget& rt, const ImageId image, int32_t x, int32_t y, const PaletteMap& paletteMap)
{
    // DrawGlyph not fully implemented for visionOS - stub
    (void)rt;
    (void)image;
    (void)x;
    (void)y;
    (void)paletteMap;
}

void X8DrawingContext::DrawTTFBitmap(
    RenderTarget& rt, TextDrawInfo* info, TTFSurface* surface, int32_t x, int32_t y, uint8_t hintingThreshold)
{
    // DrawTTFBitmap not fully implemented for visionOS - stub
    (void)rt;
    (void)info;
    (void)surface;
    (void)x;
    (void)y;
    (void)hintingThreshold;
}
