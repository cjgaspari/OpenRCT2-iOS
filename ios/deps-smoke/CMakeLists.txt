cmake_minimum_required(VERSION 3.24)

project(openrct2_ios_deps_smoke LANGUAGES C CXX)

if (NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "The dependency smoke target must cross-compile for iOS")
endif ()
if (NOT CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    message(FATAL_ERROR "The dependency smoke target requires an arm64-only slice")
endif ()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(SDL2 CONFIG REQUIRED)
find_package(ICU 59.0 REQUIRED COMPONENTS uc)
find_package(Freetype REQUIRED)
find_package(PNG 1.6 REQUIRED)
find_package(ZLIB REQUIRED)
find_package(zstd CONFIG REQUIRED)
find_package(libzip CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

if (TARGET SDL2::SDL2-static)
    set(OPENRCT2_SDL_TARGET SDL2::SDL2-static)
elseif (TARGET SDL2::SDL2)
    set(OPENRCT2_SDL_TARGET SDL2::SDL2)
else ()
    message(FATAL_ERROR "SDL2 did not provide a linkable CMake target")
endif ()

if (TARGET zstd::libzstd)
    set(OPENRCT2_ZSTD_TARGET zstd::libzstd)
elseif (TARGET zstd::libzstd_static)
    set(OPENRCT2_ZSTD_TARGET zstd::libzstd_static)
elseif (TARGET zstd::libzstd_shared)
    set(OPENRCT2_ZSTD_TARGET zstd::libzstd_shared)
else ()
    message(FATAL_ERROR "zstd did not provide a linkable CMake target")
endif ()

add_executable(openrct2-ios-deps-smoke main.cpp)
target_link_options(openrct2-ios-deps-smoke PRIVATE "LINKER:-no_warn_duplicate_libraries")
target_link_libraries(openrct2-ios-deps-smoke PRIVATE
    ${OPENRCT2_SDL_TARGET}
    ICU::uc
    Freetype::Freetype
    PNG::PNG
    ZLIB::ZLIB
    ${OPENRCT2_ZSTD_TARGET}
    libzip::zip
    nlohmann_json::nlohmann_json)

set_target_properties(openrct2-ios-deps-smoke PROPERTIES
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2")
