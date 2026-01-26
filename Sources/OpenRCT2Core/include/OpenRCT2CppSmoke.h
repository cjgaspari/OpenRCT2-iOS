#ifndef OPENRCT2_CPP_SMOKE_H
#define OPENRCT2_CPP_SMOKE_H

#ifdef __cplusplus
#include <cstdint>

// Minimal C++ type to validate Swift C++ interop during builds.
struct OpenRCT2CppSmokeTest {
    int32_t value;
    constexpr explicit OpenRCT2CppSmokeTest(int32_t input) : value(input) {}
    constexpr int32_t doubleValue() const { return value * 2; }
};
#endif

#endif // OPENRCT2_CPP_SMOKE_H
