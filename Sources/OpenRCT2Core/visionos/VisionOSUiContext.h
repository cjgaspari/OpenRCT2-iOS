/****************************************************************************
 * VisionOSUiContext - visionOS implementation of IUiContext
 * 
 * VOS-035: Full GameContext Initialization
 * - Creates full OpenRCT2 Context with proper platform environment
 * - Integrates with real Painter and drawing engine
 * - Supports Swift-managed game loop (40Hz ticks)
 * - Exposes frame buffer for Metal rendering
 * 
 * VOS-036: Proper drawing engine with game palette
 * VOS-037: Asset path discovery for visionOS bundle
 ****************************************************************************/

#pragma once

#include <memory>

// Forward declarations to avoid pulling in problematic C++ headers for visionOS SDK
namespace OpenRCT2
{
    struct IContext;
    struct IPlatformEnvironment;
    
    namespace Ui
    {
        struct IUiContext;

        // Factory functions
        [[nodiscard]] std::unique_ptr<IUiContext> CreateVisionOSUiContext();

        // Concrete visionOS context API for Swift interop convenience
        class VisionOSUiContext;
        VisionOSUiContext* AsVisionOSUiContext(IUiContext* ctx);
    } // namespace Ui
    
    // VOS-035: Factory for visionOS platform environment
    [[nodiscard]] std::unique_ptr<IPlatformEnvironment> CreateVisionOSPlatformEnvironment();
} // namespace OpenRCT2
