/*****************************************************************************
 * Copyright (c) 2014-2026 OpenRCT2 developers
 *
 * For a complete list of all authors, please refer to contributors.md
 * Interested in contributing? Visit https://github.com/OpenRCT2/OpenRCT2
 *
 * OpenRCT2 is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "FileStream.h"

#include "Path.hpp"
#include "String.hpp"

#include <string_view>

#ifndef _WIN32
    #include <cerrno>
    #include <sys/stat.h>
#else
    #include <io.h>
#endif

#ifdef _MSC_VER
    #define ftello _ftelli64
    #define fseeko _fseeki64
#endif

namespace OpenRCT2
{
    FileStream::FileStream(const fs::path& path, FileMode fileMode)
        : FileStream(path.u8string(), fileMode)
    {
    }

    FileStream::FileStream(const std::string& path, FileMode fileMode)
        : FileStream(path.c_str(), fileMode)
    {
    }

    FileStream::FileStream(std::string_view path, FileMode fileMode)
        : FileStream(std::string(path), fileMode)
    {
    }

    FileStream::FileStream(const utf8* path, FileMode fileMode)
    {
        const char* mode;
        switch (fileMode)
        {
            case FileMode::open:
                mode = "rb";
                _canRead = true;
                _canWrite = false;
                break;
            case FileMode::write:
                mode = "w+b";
                _canRead = true;
                _canWrite = true;
                break;
            case FileMode::append:
                mode = "a";
                _canRead = false;
                _canWrite = true;
                break;
            default:
                throw;
        }

        // Diagnostic logging for visionOS file access
        printf("[FileStream] Attempting to open: %s (mode: %s)\n", path, mode);
        fprintf(stderr, "[FileStream] Attempting to open: %s (mode: %s)\n", path, mode);
        fflush(stderr);

        // Make sure the directory exists before writing to a file inside it
        if (_canWrite)
        {
            std::string directory = Path::GetDirectory(path);
            if (!Path::DirectoryExists(directory))
            {
                Path::CreateDirectory(directory);
            }
        }

#ifdef _WIN32
        auto pathW = String::toWideChar(path);
        auto modeW = String::toWideChar(mode);
        _file = _wfopen(pathW.c_str(), modeW.c_str());
#else
        if (fileMode == FileMode::open)
        {
            struct stat fileStat;
            // Check if file exists and is a regular file
            int statResult = stat(path, &fileStat);
            printf("[FileStream] stat() result for %s: %d\n", path, statResult);
            if (statResult != 0)
            {
                printf("[FileStream] File not found or inaccessible: %s (errno: %d)\n", path, errno);
                fprintf(stderr, "[FileStream] File not found or inaccessible: %s (errno: %d)\n", path, errno);
            }
            else
            {
                printf(
                    "[FileStream] File exists, size: %zu, is_regular: %d\n", static_cast<size_t>(fileStat.st_size),
                    S_ISREG(fileStat.st_mode) ? 1 : 0);
            }
            // Only allow regular files to be opened as its possible to open directories.
            if (statResult == 0 && S_ISREG(fileStat.st_mode))
            {
                _file = fopen(path, mode);
            }
        }
        else
        {
            _file = fopen(path, mode);
        }
#endif
        if (_file == nullptr)
        {
            printf("[FileStream] FAILED to open: %s\n", path);
            fprintf(stderr, "[FileStream] FAILED to open: %s\n", path);
            fflush(stderr);
            throw IOException(String::stdFormat("Unable to open '%s'", path));
        }
        printf("[FileStream] Successfully opened: %s\n", path);
        fflush(stdout);

#ifdef _WIN32
        _fileSize = _filelengthi64(_fileno(_file));
#else
        std::error_code ec;
        _fileSize = fs::file_size(fs::u8path(path), ec);
#endif

        _ownsFilePtr = true;
    }

    FileStream::~FileStream()
    {
        if (!_disposed)
        {
            _disposed = true;
            if (_ownsFilePtr)
            {
                fclose(_file);
            }
        }
    }

    bool FileStream::CanRead() const
    {
        return _canRead;
    }

    bool FileStream::CanWrite() const
    {
        return _canWrite;
    }

    uint64_t FileStream::GetLength() const
    {
        return _fileSize;
    }

    uint64_t FileStream::GetPosition() const
    {
        return ftello(_file);
    }

    void FileStream::SetPosition(uint64_t position)
    {
        Seek(position, STREAM_SEEK_BEGIN);
    }

    void FileStream::Seek(int64_t offset, int32_t origin)
    {
        switch (origin)
        {
            case STREAM_SEEK_BEGIN:
                fseeko(_file, offset, SEEK_SET);
                break;
            case STREAM_SEEK_CURRENT:
                fseeko(_file, offset, SEEK_CUR);
                break;
            case STREAM_SEEK_END:
                fseeko(_file, offset, SEEK_END);
                break;
        }
    }

    void FileStream::Read(void* buffer, uint64_t length)
    {
        if (fread(buffer, 1, static_cast<size_t>(length), _file) == length)
        {
            return;
        }
        throw IOException("Attempted to read past end of file.");
    }

    void FileStream::Write(const void* buffer, uint64_t length)
    {
        if (length == 0)
        {
            return;
        }
        if (auto count = fwrite(buffer, static_cast<size_t>(length), 1, _file); count != 1)
        {
            std::string error = "Unable to write " + std::to_string(length) + " bytes to file. Count = " + std::to_string(count)
                + ", errno = " + std::to_string(errno);
            throw IOException(error);
        }

        uint64_t position = GetPosition();
        _fileSize = std::max(_fileSize, position);
    }

    uint64_t FileStream::TryRead(void* buffer, uint64_t length)
    {
        size_t readBytes = fread(buffer, 1, static_cast<size_t>(length), _file);
        return readBytes;
    }

} // namespace OpenRCT2
