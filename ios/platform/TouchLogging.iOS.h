/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #import <Foundation/Foundation.h>
    #import <os/log.h>

    // Hot-path chrome/import chatter is debug-only. Errors stay unconditional.
    #ifndef OPENRCT2_TOUCH_VERBOSE_LOG
        #ifdef NDEBUG
            #define OPENRCT2_TOUCH_VERBOSE_LOG 0
        #else
            #define OPENRCT2_TOUCH_VERBOSE_LOG 1
        #endif
    #endif

    #if OPENRCT2_TOUCH_VERBOSE_LOG
        #define TOUCH_LOG_INFO(fmt, ...)                                                                                       \
            do                                                                                                                 \
            {                                                                                                                  \
                NSLog((fmt), ##__VA_ARGS__);                                                                                   \
                os_log_info(OS_LOG_DEFAULT, "%{public}@", [NSString stringWithFormat:(fmt), ##__VA_ARGS__]);                   \
            } while (0)
        #define TOUCH_OS_LOG_INFO(fmt, ...) os_log_info(OS_LOG_DEFAULT, fmt, ##__VA_ARGS__)
    #else
        #define TOUCH_LOG_INFO(fmt, ...)                                                                                       \
            do                                                                                                                 \
            {                                                                                                                  \
            } while (0)
        #define TOUCH_OS_LOG_INFO(fmt, ...)                                                                                    \
            do                                                                                                                 \
            {                                                                                                                  \
            } while (0)
    #endif

    #define TOUCH_LOG_ERROR(fmt, ...)                                                                                          \
        do                                                                                                                     \
        {                                                                                                                      \
            NSLog((fmt), ##__VA_ARGS__);                                                                                       \
            os_log_error(OS_LOG_DEFAULT, "%{public}@", [NSString stringWithFormat:(fmt), ##__VA_ARGS__]);                      \
        } while (0)

#endif // TARGET_OS_IOS
