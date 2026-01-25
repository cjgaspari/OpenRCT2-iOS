# OpenRCT2 iOS Build Configuration
cmake_minimum_required(VERSION 3.24)

project(openrct2-ios CXX C OBJCXX)

set(CMAKE_VERBOSE_MAKEFILE on)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Debug level
set(DEBUG_LEVEL 0 CACHE STRING "Select debug level for compilation. Use value in range 0–3.")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DDEBUG=${DEBUG_LEVEL}")

# Get the root OpenRCT2 directory
get_filename_component(ORCT2_ROOT "${CMAKE_SOURCE_DIR}/../.." REALPATH)

# iOS-specific settings
set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "iOS deployment target")
set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)
set(CMAKE_IOS_INSTALL_COMBINED YES)

# Disable features not needed/available on iOS
add_definitions(-DDISABLE_DISCORD_RPC)
add_definitions(-DDISABLE_OPENGL)
add_definitions(-DDISABLE_HTTP)
add_definitions(-DDISABLE_NETWORK)
add_definitions(-D__STDC_LIMIT_MACROS)
add_definitions(-DSDL_MAIN_HANDLED)
add_definitions(-DENABLE_SCRIPTING)
add_definitions(-DHAVE_STDINT_H)
# iOS platform define
add_definitions(-D__IOS__)
add_definitions(-DOPENRCT2_IOS)

# Download iOS dependencies
include(ExternalProject)

set(IOS_DEPS_VERSION "1")
set(IOS_DEPS_DIR "${CMAKE_BINARY_DIR}/libs")

# For now, we'll build SDL2 from source or use a prebuilt version
# SDL2 iOS is available from: https://github.com/libsdl-org/SDL/releases

# SDL2 Framework location (user needs to provide this)
set(SDL2_FRAMEWORK_PATH "" CACHE PATH "Path to SDL2.framework for iOS")

if(NOT SDL2_FRAMEWORK_PATH)
    message(STATUS "SDL2_FRAMEWORK_PATH not set. Will attempt to download SDL2...")
    
    # Download SDL2 iOS framework
    set(SDL2_VERSION "2.30.9")
    set(SDL2_URL "https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.dmg")
    
    ExternalProject_Add(SDL2_download
        URL ${SDL2_URL}
        DOWNLOAD_DIR ${IOS_DEPS_DIR}
        SOURCE_DIR ${IOS_DEPS_DIR}/SDL2
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
        INSTALL_COMMAND ""
        LOG_DOWNLOAD 1
    )
endif()

# Compiler flags
set(COMMON_COMPILE_OPTIONS "-fstrict-aliasing -Wundef -Wmissing-declarations -Winit-self")
set(COMMON_COMPILE_OPTIONS "${COMMON_COMPILE_OPTIONS} -Wno-unknown-pragmas -Wno-unused-function -Wno-missing-braces")
set(COMMON_COMPILE_OPTIONS "${COMMON_COMPILE_OPTIONS} -Wno-comment -Wshadow -Wnonnull")
set(COMMON_COMPILE_OPTIONS "${COMMON_COMPILE_OPTIONS} -fPIC")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${COMMON_COMPILE_OPTIONS} -Wnon-virtual-dtor")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-char8_t -Wno-deprecated-declarations")

# List all OpenRCT2 source files
file(GLOB_RECURSE LIBOPENRCT2_SOURCES
    "${ORCT2_ROOT}/src/thirdparty/duktape/duktape.cpp"
    "${ORCT2_ROOT}/src/openrct2/*.cpp"
    "${ORCT2_ROOT}/src/openrct2/*.h"
    "${ORCT2_ROOT}/src/openrct2/*.hpp")

file(GLOB_RECURSE OPENRCT2_GUI_SOURCES
    "${ORCT2_ROOT}/src/openrct2-ui/*.cpp"
    "${ORCT2_ROOT}/src/openrct2-ui/*.h"
    "${ORCT2_ROOT}/src/openrct2-ui/*.hpp"
    "${ORCT2_ROOT}/src/openrct2-ui/*.mm")

# iOS-specific sources
set(OPENRCT2_IOS_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/app/main.mm"
    "${CMAKE_CURRENT_SOURCE_DIR}/app/UiContext.iOS.mm"
)

# Create libraries
add_library(libopenrct2 STATIC ${LIBOPENRCT2_SOURCES})

target_include_directories(libopenrct2 PRIVATE 
    "${ORCT2_ROOT}/src/thirdparty/duktape/"
    "${ORCT2_ROOT}/src/thirdparty"
)

# Note: Full build requires these dependencies (for PoC, some may be stubbed):
# - SDL2 (required)
# - libpng (required for sprites)  
# - zlib (required for save files)
# - zstd (required for compression)
# - ICU (required for Unicode)
# - freetype (required for fonts)
# - speexdsp (required for audio resampling)
# - Vorbis/FLAC (optional - audio)
# - OpenSSL (optional - networking, disabled)
# - libcurl (optional - HTTP, disabled)

message(STATUS "OpenRCT2 iOS build configuration complete")
message(STATUS "ORCT2_ROOT: ${ORCT2_ROOT}")
message(STATUS "iOS deployment target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "")
message(STATUS "To build, you need to provide iOS-compatible dependencies:")
message(STATUS "  - SDL2.framework (iOS)")
message(STATUS "  - Other libs: png, zlib, zstd, icu, freetype, speexdsp")
message(STATUS "")
message(STATUS "Consider using vcpkg with iOS triplet or building dependencies manually.")
