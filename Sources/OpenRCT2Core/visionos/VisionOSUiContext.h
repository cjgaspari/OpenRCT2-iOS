/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext (stub)
 ****************************************************************************/

#pragma once

// Forward declarations to avoid pulling in problematic C++ headers for visionOS SDK
namespace OpenRCT2
{
    namespace Drawing
    {
        class X8DrawingEngine;
    }

    namespace Ui
    {
        struct IUiContext;

        // Factory - returns raw pointer, caller takes ownership
        // Use std::unique_ptr<IUiContext>(CreateVisionOSUiContext()) at call site
        [[nodiscard]] IUiContext* CreateVisionOSUiContext();

        // Concrete visionOS context API for Swift interop convenience
        class VisionOSUiContext;
        VisionOSUiContext* AsVisionOSUiContext(IUiContext* ctx);
    } // namespace Ui
} // namespace OpenRCT2
