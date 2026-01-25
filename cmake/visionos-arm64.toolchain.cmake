# visionOS Device Toolchain for OpenRCT2
# Configured for Apple Vision Pro hardware
set(CMAKE_SYSTEM_NAME xros)
set(CMAKE_OSX_SYSROOT xros)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 2.0)

# SDK paths
execute_process(
    COMMAND xcrun --sdk xros --show-sdk-path
    OUTPUT_VARIABLE XROS_SDK_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Dependency paths (using same vcpkg installation as simulator for now)
set(VCPKG_ROOT "/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-vcpkg/installed/arm64-xros")
set(ICU_ROOT "/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-deps/icu-ios")

# Set up CMake search paths
set(CMAKE_FIND_ROOT_PATH 
    ${VCPKG_ROOT}
    ${ICU_ROOT}
    ${XROS_SDK_PATH}
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Force static linking
set(BUILD_SHARED_LIBS OFF CACHE BOOL "")
set(CMAKE_FIND_FRAMEWORK LAST)

# Define platform
add_compile_definitions(__VISIONOS__)

# Tell CMake about our ICU installation
set(ICU_ROOT "${ICU_ROOT}" CACHE PATH "ICU installation")
set(ICU_INCLUDE_DIR "${ICU_ROOT}/include" CACHE PATH "ICU includes")
set(ICU_UC_LIBRARY "${ICU_ROOT}/lib/libicuuc.a" CACHE FILEPATH "ICU uc library")
set(ICU_I18N_LIBRARY "${ICU_ROOT}/lib/libicui18n.a" CACHE FILEPATH "ICU i18n library")
set(ICU_DATA_LIBRARY "${ICU_ROOT}/lib/libicudata.a" CACHE FILEPATH "ICU data library")

# Tell CMake about FreeType
set(FREETYPE_INCLUDE_DIR_freetype2 "${VCPKG_ROOT}/include/freetype2" CACHE PATH "")
set(FREETYPE_INCLUDE_DIR_ft2build "${VCPKG_ROOT}/include" CACHE PATH "")
set(FREETYPE_LIBRARY_RELEASE "${VCPKG_ROOT}/lib/libfreetype.a" CACHE FILEPATH "")

# Tell CMake about zlib
set(ZLIB_INCLUDE_DIR "${VCPKG_ROOT}/include" CACHE PATH "")
set(ZLIB_LIBRARY_RELEASE "${VCPKG_ROOT}/lib/libz.a" CACHE FILEPATH "")

# Tell CMake about libpng
set(PNG_PNG_INCLUDE_DIR "${VCPKG_ROOT}/include" CACHE PATH "")
set(PNG_LIBRARY_RELEASE "${VCPKG_ROOT}/lib/libpng16.a" CACHE FILEPATH "")

# CMake module paths for vcpkg packages
set(zstd_DIR "${VCPKG_ROOT}/share/zstd" CACHE PATH "")
set(libzip_DIR "${VCPKG_ROOT}/share/libzip" CACHE PATH "")

# OpenRCT2 options - disable unsupported features on visionOS
set(DISABLE_DISCORD_RPC ON CACHE BOOL "Discord RPC not supported on visionOS")
set(DISABLE_OPENGL ON CACHE BOOL "OpenGL not needed - using Metal instead")
set(DISABLE_SDL ON CACHE BOOL "SDL not supported on visionOS")
set(DISABLE_HTTP ON CACHE BOOL "HTTP disabled for visionOS")
set(DISABLE_NETWORK ON CACHE BOOL "Network disabled for visionOS")
set(ENABLE_SCRIPTING OFF CACHE BOOL "Scripting disabled for visionOS")
set(DISABLE_FLAC ON CACHE BOOL "FLAC disabled for visionOS")
set(DISABLE_VORBIS ON CACHE BOOL "Vorbis disabled for visionOS")

# visionOS deployment options
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
