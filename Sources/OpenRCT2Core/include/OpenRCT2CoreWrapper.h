// OpenRCT2CoreWrapper.h - Wrapper to ensure C++ standard headers are included properly
#ifndef OPENRCT2_CORE_WRAPPER_H
#define OPENRCT2_CORE_WRAPPER_H

// Include C++ standard headers first to ensure CHAR_BIT is defined
#include <climits>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <chrono>

// Then include our headers
#include "OpenRCT2Shim.h"

#endif // OPENRCT2_CORE_WRAPPER_H
