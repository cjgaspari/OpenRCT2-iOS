/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext (stub)
 ****************************************************************************/

#pragma once

#include <memory>

#include <openrct2/ui/UiContext.h>

namespace OpenRCT2::Ui
{
    // Factory
    [[nodiscard]] std::unique_ptr<IUiContext> CreateVisionOSUiContext();
}
