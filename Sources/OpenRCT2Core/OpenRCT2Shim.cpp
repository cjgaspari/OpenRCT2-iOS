#include "include/OpenRCT2Shim.h"

#include "visionos/VisionOSUiContext.h"

#include <memory>
#include <openrct2/drawing/RenderTarget.h>

using namespace OpenRCT2::Ui;
using namespace OpenRCT2::Drawing;

// Global context and rendering state
static std::unique_ptr<IUiContext> g_uiContext;
static RenderTarget g_dummyRT = {};
static bool g_initialized = false;

bool openrct2_init(const char* configPath)
{
    if (g_initialized)
        return true;

    try
    {
        // Create visionOS-specific UI context
        g_uiContext = CreateVisionOSUiContext();

        if (!g_uiContext)
        {
            return false;
        }

        g_initialized = true;
        return true;
    }
    catch (...)
    {
        return false;
    }
}

void openrct2_shutdown(void)
{
    g_uiContext.reset();
    g_initialized = false;
}

void openrct2_tick(void)
{
    if (!g_initialized || !g_uiContext)
        return;

    // Process game state updates
    g_uiContext->ProcessMessages();

    // Render the current frame
    g_uiContext->Draw(g_dummyRT);
}

const uint8_t* openrct2_get_frame_buffer(void)
{
    if (!g_initialized || !g_uiContext)
        return nullptr;

    auto* visionosCtx = AsVisionOSUiContext(const_cast<IUiContext*>(g_uiContext.get()));
    if (!visionosCtx)
        return nullptr;

    return visionosCtx->GetPixelBuffer();
}

const uint8_t* openrct2_get_palette(void)
{
    if (!g_initialized || !g_uiContext)
        return nullptr;

    auto* visionosCtx = AsVisionOSUiContext(const_cast<IUiContext*>(g_uiContext.get()));
    if (!visionosCtx)
        return nullptr;

    // Return palette as source pointer from renderer
    // Note: This is BGRA format (uint32_t), caller must handle conversion
    return reinterpret_cast<const uint8_t*>(visionosCtx->GetPaletteBGRA());
}

void openrct2_touch_down(float x, float y)
{
    // TODO: Forward to OpenRCT2 input system
    (void)x;
    (void)y;
}

void openrct2_touch_moved(float x, float y)
{
    // TODO: Forward to OpenRCT2 input system
    (void)x;
    (void)y;
}

void openrct2_touch_up(float x, float y)
{
    // TODO: Forward to OpenRCT2 input system
    (void)x;
    (void)y;
}

int32_t openrct2_get_pitch(void)
{
    if (!g_initialized || !g_uiContext)
        return 1280; // Default width

    auto* visionosCtx = AsVisionOSUiContext(const_cast<IUiContext*>(g_uiContext.get()));
    if (!visionosCtx)
        return 1280;

    return visionosCtx->GetBufferPitch();
}
