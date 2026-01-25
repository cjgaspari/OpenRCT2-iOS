/****************************************************************************
 * VisionOSPlatformEnvironment - visionOS implementation of IPlatformEnvironment
 * 
 * VOS-035: Full GameContext Initialization
 * Creates the platform environment with proper paths for:
 * - App bundle resources (g1.dat, g2.dat, language files)
 * - User data in Documents folder
 * - Cache in Caches folder
 * - Configuration in Application Support
 ****************************************************************************/

// Force include limits headers early for visionOS SDK compatibility
#include <climits>
#include <cstdint>
#include <limits.h>
#include <string>

#include <openrct2/PlatformEnvironment.h>
#include <openrct2/config/Config.h>

// Objective-C headers for path discovery
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

using namespace OpenRCT2;

namespace
{
    /**
     * Simple path combining helper - avoids linking to CombinePath
     * which is implemented in the full OpenRCT2 library.
     * Uses u8string_view for compatibility with OpenRCT2 path types.
     */
    static u8string CombinePath(u8string_view a, u8string_view b)
    {
        if (a.empty()) return u8string(b);
        if (b.empty()) return u8string(a);
        
        // Check if 'a' already ends with a separator
        char last = a.back();
        if (last == '/' || last == '\\')
        {
            u8string result(a);
            result.append(b);
            return result;
        }
        u8string result(a);
        result += '/';
        result.append(b);
        return result;
    }
    
    // Directory names for RCT2 data layout
    static constexpr const char* kDirectoryNamesRCT2[] = {
        "Data",        // DATA
        "Landscapes",  // LANDSCAPE
        nullptr,       // LANGUAGE
        nullptr,       // LOG_CHAT
        nullptr,       // LOG_SERVER
        nullptr,       // NETWORK_KEY
        "ObjData",     // OBJECT
        nullptr,       // PLUGIN
        "Saved Games", // SAVE
        "Scenarios",   // SCENARIO
        nullptr,       // SCREENSHOT
        nullptr,       // SEQUENCE
        nullptr,       // SHADER
        nullptr,       // THEME
        "Tracks",      // TRACK
    };

    // Directory names for OpenRCT2 user data
    // Using const char* instead of u8string_view for C++20 compatibility
    static constexpr const char* kDirectoryNamesOpenRCT2[] = {
        "data",             // DATA
        "landscape",        // LANDSCAPE
        "language",         // LANGUAGE
        "chatlogs",         // LOG_CHAT
        "serverlogs",       // LOG_SERVER
        "keys",             // NETWORK_KEY
        "object",           // OBJECT
        "plugin",           // PLUGIN
        "save",             // SAVE
        "scenario",         // SCENARIO
        "screenshot",       // SCREENSHOT
        "sequence",         // SEQUENCE
        "shaders",          // SHADER
        "themes",           // THEME
        "track",            // TRACK
        "heightmap",        // HEIGHTMAP
        "replay",           // REPLAY
        "desyncs",          // DESYNCS
        "crash",            // CRASH
        "assetpack",        // ASSET_PACK
        "scenario_patches", // SCENARIO_PATCHES
    };

    // File names for various OpenRCT2 files
    static constexpr const char* kFileNames[] = {
        "config.ini",
        "hotkeys.dat",
        "shortcuts.json",
        "objects.idx",
        "tracks.idx",
        "scenarios.idx",
        "groups.json",
        "servers.cfg",
        "users.json",
        "highscores.dat",
        "scores.dat",
        "Saved Games/scores.dat",
        "changelog.txt",
        "plugin.store.json",
        "contributors.md",
    };

#ifdef __OBJC__
    /**
     * Get the app bundle's resource path.
     * This is where g1.dat, g2.dat, language files, etc. are bundled.
     */
    static std::string GetBundleResourcePath()
    {
        @autoreleasepool
        {
            NSBundle* bundle = [NSBundle mainBundle];
            if (bundle && bundle.resourcePath)
            {
                return std::string(bundle.resourcePath.UTF8String);
            }
            return std::string();
        }
    }

    /**
     * Get the Documents directory for user-provided data.
     * Users can place RCT2 data files here via Files.app.
     */
    static std::string GetDocumentsPath()
    {
        @autoreleasepool
        {
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            if (paths.count > 0)
            {
                return std::string([paths.firstObject UTF8String]);
            }
            return std::string();
        }
    }

    /**
     * Get the Application Support directory for configuration.
     */
    static std::string GetApplicationSupportPath()
    {
        @autoreleasepool
        {
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
            if (paths.count > 0)
            {
                NSString* basePath = paths.firstObject;
                NSString* appPath = [basePath stringByAppendingPathComponent:@"OpenRCT2"];
                
                // Create directory if needed
                [[NSFileManager defaultManager] createDirectoryAtPath:appPath 
                                          withIntermediateDirectories:YES 
                                                           attributes:nil 
                                                                error:nil];
                return std::string(appPath.UTF8String);
            }
            return std::string();
        }
    }

    /**
     * Get the Caches directory for cache files.
     */
    static std::string GetCachesPath()
    {
        @autoreleasepool
        {
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            if (paths.count > 0)
            {
                NSString* basePath = paths.firstObject;
                NSString* appPath = [basePath stringByAppendingPathComponent:@"OpenRCT2"];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:appPath 
                                          withIntermediateDirectories:YES 
                                                           attributes:nil 
                                                                error:nil];
                return std::string(appPath.UTF8String);
            }
            return std::string();
        }
    }

    /**
     * Check if a path exists and is a directory.
     */
    static bool DirectoryExists(const std::string& path)
    {
        @autoreleasepool
        {
            BOOL isDir = NO;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:path.c_str()] 
                                                               isDirectory:&isDir];
            return exists && isDir;
        }
    }
#else
    static std::string GetBundleResourcePath() { return "."; }
    static std::string GetDocumentsPath() { return "."; }
    static std::string GetApplicationSupportPath() { return "."; }
    static std::string GetCachesPath() { return "."; }
    static bool DirectoryExists(const std::string&) { return false; }
#endif

} // anonymous namespace

namespace OpenRCT2
{
    /**
     * VisionOS Platform Environment Implementation.
     * 
     * Directory structure:
     * - DirBase::openrct2  -> App bundle resources (read-only game data)
     * - DirBase::user      -> Documents/OpenRCT2 (user saves, scenarios, etc.)
     * - DirBase::config    -> Application Support/OpenRCT2 (config files)
     * - DirBase::cache     -> Caches/OpenRCT2 (object/scenario indices)
     * - DirBase::rct1      -> Documents/OpenRCT2/rct1 (optional RCT1 data)
     * - DirBase::rct2      -> Documents/OpenRCT2/rct2 OR bundle (RCT2 data)
     * - DirBase::documentation -> App bundle (changelog, contributors)
     */
    class VisionOSPlatformEnvironment final : public IPlatformEnvironment
    {
    private:
        u8string _basePath[kDirBaseCount];

    public:
        VisionOSPlatformEnvironment()
        {
            // Get system paths
            auto bundlePath = GetBundleResourcePath();
            auto documentsPath = GetDocumentsPath();
            auto appSupportPath = GetApplicationSupportPath();
            auto cachesPath = GetCachesPath();
            
            // User data directory within Documents
            auto userPath = CombinePath(documentsPath, "OpenRCT2");
            
            // Initialize base paths
            _basePath[static_cast<size_t>(DirBase::openrct2)] = bundlePath;
            _basePath[static_cast<size_t>(DirBase::user)] = userPath;
            _basePath[static_cast<size_t>(DirBase::config)] = appSupportPath;
            _basePath[static_cast<size_t>(DirBase::cache)] = cachesPath;
            _basePath[static_cast<size_t>(DirBase::documentation)] = bundlePath;
            
            // RCT2 data: Check bundle first, then user documents
            // If bundled with app, use that. Otherwise look in user's Documents.
            auto bundledRCT2 = CombinePath(bundlePath, "rct2");
            auto userRCT2 = CombinePath(userPath, "rct2");
            
            if (DirectoryExists(bundledRCT2))
            {
                _basePath[static_cast<size_t>(DirBase::rct2)] = bundledRCT2;
            }
            else
            {
                _basePath[static_cast<size_t>(DirBase::rct2)] = userRCT2;
            }
            
            // RCT1 data: always user-provided
            _basePath[static_cast<size_t>(DirBase::rct1)] = CombinePath(userPath, "rct1");
        }

        u8string GetDirectoryPath(DirBase base) const override
        {
            auto index = static_cast<size_t>(base);
            if (index < kDirBaseCount)
            {
                return _basePath[index];
            }
            return u8string();
        }

        u8string GetDirectoryPath(DirBase base, DirId did) const override
        {
            auto basePath = GetDirectoryPath(base);
            if (basePath.empty())
            {
                return u8string();
            }
            
            const char* directoryName = nullptr;
            auto didIndex = static_cast<size_t>(did);
            
            switch (base)
            {
                case DirBase::rct1:
                case DirBase::rct2:
                    if (didIndex < std::size(kDirectoryNamesRCT2))
                    {
                        directoryName = kDirectoryNamesRCT2[didIndex];
                    }
                    break;
                    
                case DirBase::openrct2:
                case DirBase::user:
                case DirBase::config:
                    if (didIndex < std::size(kDirectoryNamesOpenRCT2))
                    {
                        directoryName = kDirectoryNamesOpenRCT2[didIndex];
                    }
                    break;
                    
                default:
                    if (didIndex < std::size(kDirectoryNamesOpenRCT2))
                    {
                        directoryName = kDirectoryNamesOpenRCT2[didIndex];
                    }
                    break;
            }
            
            if (directoryName == nullptr)
            {
                return basePath;
            }
            
            return CombinePath(basePath, directoryName);
        }

        u8string GetFilePath(PathId pathid) const override
        {
            DirBase dirbase = GetDefaultBaseDirectory(pathid);
            auto basePath = GetDirectoryPath(dirbase);
            auto pathidIndex = static_cast<size_t>(pathid);
            
            if (pathidIndex < std::size(kFileNames))
            {
                return CombinePath(basePath, kFileNames[pathidIndex]);
            }
            
            return basePath;
        }

        u8string FindFile(DirBase base, DirId did, u8string_view fileName) const override
        {
            auto dataPath = GetDirectoryPath(base, did);
            return CombinePath(dataPath, fileName);
        }

        void SetBasePath(DirBase base, u8string_view path) override
        {
            auto index = static_cast<size_t>(base);
            if (index < kDirBaseCount)
            {
                _basePath[index] = u8string(path);
            }
        }

        bool IsUsingClassic() const override
        {
            // visionOS doesn't support RCT Classic detection for now
            return false;
        }

    private:
        static DirBase GetDefaultBaseDirectory(PathId pathid)
        {
            switch (pathid)
            {
                case PathId::config:
                case PathId::configShortcutsLegacy:
                case PathId::configShortcuts:
                    return DirBase::config;
                    
                case PathId::cacheObjects:
                case PathId::cacheTracks:
                case PathId::cacheScenarios:
                    return DirBase::cache;
                    
                case PathId::scoresRCT2:
                    return DirBase::rct2;
                    
                case PathId::changelog:
                case PathId::contributors:
                    return DirBase::documentation;
                    
                default:
                    return DirBase::user;
            }
        }
    };

    /**
     * Factory function to create the visionOS platform environment.
     */
    std::unique_ptr<IPlatformEnvironment> CreateVisionOSPlatformEnvironment()
    {
        return std::make_unique<VisionOSPlatformEnvironment>();
    }

} // namespace OpenRCT2
