/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <string>

struct SDL_Window;

namespace OpenRCT2::Ui
{
    std::string ShowRCT2DirectoryImporter(SDL_Window* window, const std::string& title);
}
