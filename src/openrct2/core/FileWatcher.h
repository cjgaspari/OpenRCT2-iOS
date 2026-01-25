/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#pragma once

#include "StringTypes.h"

#include <functional>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
    #include "FileSystem.hpp"

typedef void* HANDLE;
#elif defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH || TARGET_OS_VISION
        // iOS/visionOS doesn't support FSEvents
        #define OPENRCT2_NO_FILE_WATCHER
    #else
        #include <CoreServices/CoreServices.h>
    #endif
#endif

/**
 * Creates a new thread that watches a directory tree for file modifications.
 */
class FileWatcher
{
private:
    std::thread _watchThread;
#if defined(_WIN32)
    fs::path _path;
    HANDLE _directoryHandle{};
#elif defined(__linux__)
    struct FileDescriptor
    {
        int Fd = -1;

        ~FileDescriptor();
        void Initialise();
        void Close();
    };

    struct WatchDescriptor
    {
        int const Fd;
        int const Wd;
        std::string const Path;

        WatchDescriptor(int fd, const std::string& path);
        ~WatchDescriptor();
    };

    FileDescriptor _fileDesc;
    std::vector<WatchDescriptor> _watchDescs;
#elif defined(__APPLE__) && !defined(OPENRCT2_NO_FILE_WATCHER)
    FSEventStreamRef _stream{};
    CFRunLoopRef _runLoop{};
#endif

public:
    std::function<void(u8string_view path)> OnFileChanged;

    FileWatcher(u8string_view directoryPath);
    ~FileWatcher();

private:
#if defined(_WIN32) || defined(__linux__)
    bool _finished{};
#elif defined(__APPLE__) && !defined(OPENRCT2_NO_FILE_WATCHER)
    static void FSEventsCallback(
        ConstFSEventStreamRef streamRef, void* clientCallBackInfo, size_t numEvents, void* eventPaths,
        const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[]);
#endif

    void WatchDirectory();
};
