/**
 * OpenRCT2 visionOS Platform Header
 * Defines platform-specific macros and includes for visionOS builds
 */

#ifndef OPENRCT2_VISIONOS_H
#define OPENRCT2_VISIONOS_H

#ifdef __VISIONOS__

    // visionOS is a Unix-like platform based on xrOS kernel
    #define OPENRCT2_VISIONOS 1
    
    // Disable unsupported platforms
    #undef _WIN32
    #undef __APPLE__  // Re-enabled below as OPENRCT2_VISIONOS
    #define __APPLE__  // Keep Apple macros for Foundation frameworks

    // Platforms that visionOS can use
    #define OPENRCT2_PLATFORM_UNIX 1
    
    // Disable SDL entirely for visionOS - uses native visionOS/RealityKit instead
    #define DISABLE_SDL 1
    
    // Audio will be handled by AVFoundation instead
    #define DISABLE_OPENAL 1
    
    // OpenGL not available, using Metal instead
    #define DISABLE_OPENGL 1

    // Network capabilities disabled for appstore compliance
    #define DISABLE_NETWORK 1
    
    // Discord RPC not supported
    #define DISABLE_DISCORD_RPC 1

#endif // __VISIONOS__

#endif // OPENRCT2_VISIONOS_H
