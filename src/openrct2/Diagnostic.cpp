/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "Diagnostic.h"

#include "core/Console.hpp"
#include "core/EnumUtils.hpp"
#include "core/String.hpp"

#include <cstdarg>
#include <cstdio>

#ifdef __ANDROID__
    #include <android/log.h>
#endif

// visionOS/iOS: Use os_log for reliable console logging
#if defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IOS || TARGET_OS_VISION
        #define OPENRCT2_USE_OS_LOG 1
        #include <os/log.h>
static os_log_t g_diagnosticLog = nullptr;
static os_log_t getDiagnosticLog()
{
    if (!g_diagnosticLog)
    {
        g_diagnosticLog = os_log_create("io.openrct2.OpenRCT2", "Diagnostic");
    }
    return g_diagnosticLog;
}
    #endif
#endif

using namespace OpenRCT2;

[[maybe_unused]] static bool _log_location_enabled = true;
bool _log_levels[EnumValue(DiagnosticLevel::Count)] = {
    true, true, true, false, true,
};

static FILE* diagnostic_get_stream(DiagnosticLevel level)
{
    switch (level)
    {
        case DiagnosticLevel::Verbose:
        case DiagnosticLevel::Information:
            return stdout;
        default:
            return stderr;
    }
}

#ifdef __ANDROID__

int _android_log_priority[EnumValue(DiagnosticLevel::Count)] = {
    ANDROID_LOG_FATAL, ANDROID_LOG_ERROR, ANDROID_LOG_WARN, ANDROID_LOG_VERBOSE, ANDROID_LOG_INFO,
};

void DiagnosticLog(DiagnosticLevel diagnosticLevel, const char* format, ...)
{
    va_list args;

    if (!_log_levels[EnumValue(diagnosticLevel)])
        return;

    va_start(args, format);
    __android_log_vprint(_android_log_priority[EnumValue(diagnosticLevel)], "OpenRCT2", format, args);
    va_end(args);
}

void DiagnosticLogWithLocation(
    DiagnosticLevel diagnosticLevel, const char* file, const char* function, int32_t line, const char* format, ...)
{
    va_list args;
    char buf[1024];

    if (!_log_levels[EnumValue(diagnosticLevel)])
        return;

    snprintf(buf, 1024, "[%s:%d (%s)]: ", file, line, function);

    va_start(args, format);
    __android_log_vprint(_android_log_priority[EnumValue(diagnosticLevel)], file, format, args);
    va_end(args);
}

#else

static constexpr const char* kLevelStrings[] = {
    "FATAL", "ERROR", "WARNING", "VERBOSE", "INFO",
};

    #ifdef OPENRCT2_USE_OS_LOG
// Map DiagnosticLevel to os_log_type_t
static os_log_type_t getOsLogType(DiagnosticLevel level)
{
    switch (level)
    {
        case DiagnosticLevel::Fatal:
            return OS_LOG_TYPE_FAULT;
        case DiagnosticLevel::Error:
            return OS_LOG_TYPE_ERROR;
        case DiagnosticLevel::Warning:
            return OS_LOG_TYPE_DEFAULT;
        case DiagnosticLevel::Verbose:
            return OS_LOG_TYPE_DEBUG;
        case DiagnosticLevel::Information:
        default:
            return OS_LOG_TYPE_INFO;
    }
}
    #endif

static void DiagnosticPrint(DiagnosticLevel level, const std::string& prefix, const std::string& msg)
{
    auto stream = diagnostic_get_stream(level);
    if (stream == stdout)
        Console::WriteLine("%s%s", prefix.c_str(), msg.c_str());
    else
        Console::Error::WriteLine("%s%s", prefix.c_str(), msg.c_str());

    #ifdef OPENRCT2_USE_OS_LOG
    // Also log via os_log for visionOS/iOS console visibility
    auto fullMsg = prefix + msg;
    os_log_with_type(getDiagnosticLog(), getOsLogType(level), "%{public}s", fullMsg.c_str());
    #endif
}

void DiagnosticLog(DiagnosticLevel diagnosticLevel, const char* format, ...)
{
    va_list args;
    if (_log_levels[EnumValue(diagnosticLevel)])
    {
        // Level
        auto prefix = String::stdFormat("%s: ", kLevelStrings[EnumValue(diagnosticLevel)]);

        // Message
        va_start(args, format);
        auto msg = String::formatVA(format, args);
        va_end(args);

        DiagnosticPrint(diagnosticLevel, prefix, msg);
    }
}

void DiagnosticLogWithLocation(
    DiagnosticLevel diagnosticLevel, const char* file, const char* function, int32_t line, const char* format, ...)
{
    va_list args;
    if (_log_levels[EnumValue(diagnosticLevel)])
    {
        // Level and source code information
        std::string prefix;
        if (_log_location_enabled)
        {
            prefix = String::stdFormat("%s[%s:%d (%s)]: ", kLevelStrings[EnumValue(diagnosticLevel)], file, line, function);
        }
        else
        {
            prefix = String::stdFormat("%s: ", kLevelStrings[EnumValue(diagnosticLevel)]);
        }

        // Message
        va_start(args, format);
        auto msg = String::formatVA(format, args);
        va_end(args);

        DiagnosticPrint(diagnosticLevel, prefix, msg);
    }
}

#endif // __ANDROID__
