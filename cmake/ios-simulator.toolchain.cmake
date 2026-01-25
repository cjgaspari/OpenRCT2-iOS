# iOS Simulator Toolchain for OpenRCT2
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_SYSROOT iphonesimulator)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)

# SDK paths
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE IOS_SDK_PATH
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Dependency paths
set(VCPKG_ROOT "/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-vcpkg/installed/arm64-ios-simulator")
set(ICU_ROOT "/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-deps/icu-ios")
set(SDL2_ROOT "/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-deps/SDL2.framework")

# Set up CMake search paths
set(CMAKE_FIND_ROOT_PATH 
    ${VCPKG_ROOT}
    ${ICU_ROOT}
    ${IOS_SDK_PATH}
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Force static linking
set(BUILD_SHARED_LIBS OFF CACHE BOOL "")
set(CMAKE_FIND_FRAMEWORK LAST)

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

# OpenRCT2 options
set(DISABLE_DISCORD_RPC ON CACHE BOOL "")
set(DISABLE_OPENGL ON CACHE BOOL "")
set(DISABLE_HTTP ON CACHE BOOL "")
set(DISABLE_NETWORK ON CACHE BOOL "")
set(ENABLE_SCRIPTING OFF CACHE BOOL "")
set(DISABLE_FLAC ON CACHE BOOL "Disable FLAC for now")
set(DISABLE_VORBIS ON CACHE BOOL "Disable Vorbis for now")

# Libraries / frameworks for the linker
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -framework SDL2 -F/Users/cjgaspari/Developer/OpenRCT2-iOS/ios-deps")
