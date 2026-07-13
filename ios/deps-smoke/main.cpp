/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <png.h>
#include <unicode/ustring.h>
#include <nlohmann/json.hpp>
#include <zip.h>
#include <zlib.h>
#include <zstd.h>

#include <cstdint>

int main()
{
    const auto json = nlohmann::json::object({ { "openrct2", "touch" } });
    SDL_version sdlVersion{};
    SDL_GetVersion(&sdlVersion);

    FT_Library freetype{};
    const auto freetypeResult = FT_Init_FreeType(&freetype);
    if (freetypeResult == 0)
    {
        FT_Done_FreeType(freetype);
    }

    const UChar text[] = { 0x4F, 0x70, 0x65, 0x6E, 0 };
    const auto icuLength = u_strlen(text);
    const auto* pngVersion = png_get_libpng_ver(nullptr);
    const auto* zlibVersionString = zlibVersion();
    const auto zstdVersion = ZSTD_versionNumber();
    const auto* zipVersion = zip_libzip_version();

    return static_cast<int>(
        sdlVersion.major == 0 || freetypeResult != 0 || icuLength != 4 || pngVersion == nullptr
        || zlibVersionString == nullptr || zstdVersion == 0 || zipVersion == nullptr
        || json.at("openrct2") != "touch");
}
