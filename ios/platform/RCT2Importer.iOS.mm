/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "RCT2Importer.iOS.h"

#include <SDL.h>
#include <SDL_syswm.h>
#include <UIKit/UIKit.h>
#include <zip.h>

extern "C"
{
    typedef void (*OpenRCT2TouchImportSelectionCallback)(void* context, void* url, int32_t cancelled);
    void* OpenRCT2TouchPresentRCT2ImportPanel(
        void* presenter, void* context, OpenRCT2TouchImportSelectionCallback callback);
    void OpenRCT2TouchReleaseRCT2ImportPanel(void* session);
}

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <cerrno>

namespace
{
    struct ImportPanelSelection
    {
        BOOL finished;
        NSURL* selectedURL;
    };

    static void HandleImportPanelSelection(void* context, void* url, int32_t cancelled)
    {
        auto* selection = static_cast<ImportPanelSelection*>(context);
        if (selection == nullptr || selection->finished)
        {
            return;
        }

        if (cancelled == 0 && url != nullptr)
        {
            selection->selectedURL = [static_cast<NSURL*>(url) retain];
        }
        selection->finished = YES;
    }
} // namespace

namespace OpenRCT2::Ui
{
    struct ImportPresentationContext
    {
        UIWindow* window;
        BOOL ownsWindow;
    };

    static void PumpMainRunLoop()
    {
        @autoreleasepool
        {
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
    }

    static bool IsUsablePresentationWindow(UIWindow* window)
    {
        if (window == nil || window.hidden || window.rootViewController == nil || window.windowLevel != UIWindowLevelNormal)
        {
            return false;
        }

        UISceneActivationState state = window.windowScene.activationState;
        return state == UISceneActivationStateForegroundActive || state == UISceneActivationStateForegroundInactive;
    }

    static UIWindow* GetActiveWindow(SDL_Window* window)
    {
        if (window != nullptr)
        {
            SDL_SysWMinfo windowInfo = {};
            SDL_VERSION(&windowInfo.version);
            if (SDL_GetWindowWMInfo(window, &windowInfo) == SDL_TRUE && windowInfo.subsystem == SDL_SYSWM_UIKIT
                && IsUsablePresentationWindow(windowInfo.info.uikit.window))
            {
                return windowInfo.info.uikit.window;
            }
        }

        UIWindow* fallbackWindow = nil;
        for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
        {
            if (![scene isKindOfClass:[UIWindowScene class]])
            {
                continue;
            }
            for (UIWindow* candidate in static_cast<UIWindowScene*>(scene).windows)
            {
                if (!IsUsablePresentationWindow(candidate))
                {
                    continue;
                }
                if (candidate.isKeyWindow)
                {
                    return candidate;
                }
                fallbackWindow = candidate;
            }
        }
        return fallbackWindow;
    }

    static UIWindowScene* GetActiveWindowScene()
    {
        UIWindowScene* fallbackScene = nil;
        for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
        {
            if (![scene isKindOfClass:[UIWindowScene class]])
            {
                continue;
            }

            UIWindowScene* windowScene = static_cast<UIWindowScene*>(scene);
            if (scene.activationState == UISceneActivationStateForegroundActive)
            {
                return windowScene;
            }
            if (scene.activationState == UISceneActivationStateForegroundInactive)
            {
                fallbackScene = windowScene;
            }
        }
        return fallbackScene;
    }

    static ImportPresentationContext CreatePresentationContext(SDL_Window* window)
    {
        UIWindow* activeWindow = GetActiveWindow(window);
        if (activeWindow.rootViewController != nil)
        {
            NSLog(
                @"[OpenRCT2Touch] import: using existing presenter window class=%@ root=%@ level=%.0f",
                NSStringFromClass(activeWindow.class), NSStringFromClass(activeWindow.rootViewController.class),
                activeWindow.windowLevel);
            return { [activeWindow retain], NO };
        }

        UIWindowScene* windowScene = GetActiveWindowScene();
        if (windowScene == nil)
        {
            NSLog(@"[OpenRCT2Touch] import: no foreground window scene available");
            return { nil, NO };
        }

        UIViewController* rootViewController = [[UIViewController alloc] init];
        rootViewController.view.backgroundColor = UIColor.blackColor;

        UIWindow* presentationWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
        presentationWindow.frame = windowScene.coordinateSpace.bounds;
        presentationWindow.rootViewController = rootViewController;
        [rootViewController release];
        [presentationWindow makeKeyAndVisible];
        PumpMainRunLoop();

        NSLog(@"[OpenRCT2Touch] import: created temporary presenter window");
        return { presentationWindow, YES };
    }

    static void DestroyPresentationContext(ImportPresentationContext* context)
    {
        if (context->window == nil)
        {
            return;
        }
        if (context->ownsWindow)
        {
            context->window.hidden = YES;
            context->window.rootViewController = nil;
        }
        [context->window release];
        context->window = nil;
    }

    static UIViewController* GetPresenter(UIWindow* window)
    {
        UIViewController* presenter = window.rootViewController;
        while (presenter.presentedViewController != nil)
        {
            presenter = presenter.presentedViewController;
        }
        return presenter;
    }

    static NSURL* FindChild(NSFileManager* fileManager, NSURL* directoryURL, NSString* name, BOOL requireDirectory)
    {
        NSError* error = nil;
        NSArray<NSURL*>* children = [fileManager contentsOfDirectoryAtURL:directoryURL
                                               includingPropertiesForKeys:@[ NSURLIsDirectoryKey ]
                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                    error:&error];
        if (children == nil)
        {
            return nil;
        }

        for (NSURL* child in children)
        {
            if ([child.lastPathComponent caseInsensitiveCompare:name] != NSOrderedSame)
            {
                continue;
            }

            NSNumber* isDirectory = nil;
            if (![child getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil])
            {
                return nil;
            }
            if (isDirectory.boolValue == requireDirectory)
            {
                return child;
            }
        }
        return nil;
    }

    static NSURL* FindDescendant(NSFileManager* fileManager, NSURL* directoryURL, NSArray<NSString*>* components)
    {
        NSURL* result = directoryURL;
        for (NSString* component in components)
        {
            result = FindChild(fileManager, result, component, YES);
            if (result == nil)
            {
                return nil;
            }
        }
        return result;
    }

    static BOOL ContainsG1(NSFileManager* fileManager, NSURL* directoryURL)
    {
        return directoryURL != nil && FindChild(fileManager, directoryURL, @"g1.dat", NO) != nil;
    }

    static NSURL* FindRCTClassicResources(NSFileManager* fileManager, NSURL* sourceURL)
    {
        NSMutableArray<NSURL*>* candidates = [NSMutableArray array];

        NSURL* assetsURL = FindChild(fileManager, sourceURL, @"Assets", YES);
        if (assetsURL != nil)
        {
            [candidates addObject:assetsURL];
        }

        for (NSString* appName in @[ @"RCT Classic.app", @"RCT Classic+.app" ])
        {
            NSURL* resourcesURL = FindDescendant(fileManager, sourceURL, @[ appName, @"Contents", @"Resources" ]);
            if (resourcesURL != nil)
            {
                [candidates addObject:resourcesURL];
            }
        }

        for (NSArray<NSString*>* relativePath in @[ @[ @"Contents", @"Resources" ], @[ @"Resources" ] ])
        {
            NSURL* resourcesURL = FindDescendant(fileManager, sourceURL, relativePath);
            if (resourcesURL != nil)
            {
                [candidates addObject:resourcesURL];
            }
        }

        NSString* sourceName = sourceURL.lastPathComponent;
        if ([sourceName caseInsensitiveCompare:@"Assets"] == NSOrderedSame
            || [sourceName caseInsensitiveCompare:@"Resources"] == NSOrderedSame)
        {
            [candidates addObject:sourceURL];
        }
        for (NSURL* candidate in candidates)
        {
            if (ContainsG1(fileManager, candidate))
            {
                return candidate;
            }
        }
        return nil;
    }

    static BOOL IsSupportedImportRoot(NSFileManager* fileManager, NSURL* sourceURL)
    {
        NSURL* dataURL = FindChild(fileManager, sourceURL, @"Data", YES);
        return ContainsG1(fileManager, dataURL) || FindRCTClassicResources(fileManager, sourceURL) != nil;
    }

    static NSURL* FindSupportedImportRoot(NSFileManager* fileManager, NSURL* extractedURL)
    {
        NSMutableArray<NSDictionary*>* queue = [NSMutableArray arrayWithObject:@{ @"url" : extractedURL, @"depth" : @0 }];
        while (queue.count > 0)
        {
            NSDictionary* item = queue.firstObject;
            [queue removeObjectAtIndex:0];
            NSURL* candidate = item[@"url"];
            NSUInteger depth = [item[@"depth"] unsignedIntegerValue];
            if (IsSupportedImportRoot(fileManager, candidate))
            {
                return candidate;
            }
            if (depth >= 4)
            {
                continue;
            }

            NSArray<NSURL*>* children = [fileManager contentsOfDirectoryAtURL:candidate
                                                    includingPropertiesForKeys:@[ NSURLIsDirectoryKey ]
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                         error:nil];
            for (NSURL* child in children)
            {
                NSNumber* isDirectory = nil;
                if ([child getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil]
                    && isDirectory.boolValue)
                {
                    [queue addObject:@{ @"url" : child, @"depth" : @(depth + 1) }];
                }
            }
        }
        return nil;
    }

    static void SetImportError(NSString** errorMessage, NSString* message)
    {
        if (errorMessage != nullptr && *errorMessage == nil)
        {
            *errorMessage = [message copy];
        }
    }

    static NSURL* ExtractZipArchive(
        NSFileManager* fileManager, NSURL* archiveURL, void (^updateProgress)(NSString*), NSString** errorMessage)
    {
        constexpr zip_int64_t kMaximumEntries = 100000;
        constexpr zip_uint64_t kMaximumEntryBytes = 1024ULL * 1024ULL * 1024ULL;
        constexpr zip_uint64_t kMaximumArchiveBytes = 4ULL * 1024ULL * 1024ULL * 1024ULL;

        NSURL* extractionURL = [fileManager.temporaryDirectory
            URLByAppendingPathComponent:[NSString stringWithFormat:@"rct2.zip-import-%@", NSUUID.UUID.UUIDString]
                             isDirectory:YES];
        NSError* fileError = nil;
        if (![fileManager createDirectoryAtURL:extractionURL
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:&fileError])
        {
            SetImportError(
                errorMessage,
                [NSString stringWithFormat:@"Could not prepare ZIP import: %@", fileError.localizedDescription]);
            return nil;
        }

        int zipError = 0;
        zip_t* archive = zip_open(archiveURL.fileSystemRepresentation, ZIP_RDONLY, &zipError);
        if (archive == nullptr)
        {
            char errorBuffer[256] = {};
            zip_error_to_str(errorBuffer, sizeof(errorBuffer), zipError, errno);
            SetImportError(
                errorMessage,
                [NSString stringWithFormat:@"Could not open the ZIP: %s", errorBuffer]);
            [fileManager removeItemAtURL:extractionURL error:nil];
            return nil;
        }

        const zip_int64_t entryCount = zip_get_num_entries(archive, 0);
        if (entryCount < 0 || entryCount > kMaximumEntries)
        {
            SetImportError(errorMessage, @"The ZIP contains too many files to import safely.");
            zip_close(archive);
            [fileManager removeItemAtURL:extractionURL error:nil];
            return nil;
        }

        zip_uint64_t totalBytes = 0;
        bool failed = false;
        for (zip_uint64_t index = 0; index < static_cast<zip_uint64_t>(entryCount) && !failed; index++)
        {
            zip_stat_t entry = {};
            zip_stat_init(&entry);
            if (zip_stat_index(archive, index, ZIP_FL_ENC_GUESS, &entry) != 0 || entry.name == nullptr)
            {
                SetImportError(errorMessage, @"The ZIP directory is damaged.");
                break;
            }

            NSString* rawPath = [NSString stringWithUTF8String:entry.name];
            if (rawPath == nil || [rawPath hasPrefix:@"/"] || rawPath.length > 4096)
            {
                SetImportError(errorMessage, @"The ZIP contains an unsafe file path.");
                break;
            }

            NSString* normalizedPath = [rawPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            NSMutableArray<NSString*>* safeComponents = [NSMutableArray array];
            for (NSString* component in [normalizedPath componentsSeparatedByString:@"/"])
            {
                if (component.length == 0 || [component isEqualToString:@"."])
                {
                    continue;
                }
                if ([component isEqualToString:@".."])
                {
                    SetImportError(errorMessage, @"The ZIP contains a path outside its import folder.");
                    failed = true;
                    break;
                }
                [safeComponents addObject:component];
            }
            if (failed || safeComponents.count == 0 || safeComponents.count > 64)
            {
                if (!failed)
                {
                    SetImportError(errorMessage, @"The ZIP contains an invalid file path.");
                }
                break;
            }

            zip_uint8_t operatingSystem = 0;
            zip_uint32_t externalAttributes = 0;
            mode_t fileMode = 0;
            if (zip_file_get_external_attributes(
                    archive, index, 0, &operatingSystem, &externalAttributes)
                == 0)
            {
                fileMode = static_cast<mode_t>(externalAttributes >> 16);
                if ((fileMode & S_IFMT) == S_IFLNK)
                {
                    SetImportError(errorMessage, @"The ZIP contains a symbolic link, which cannot be imported safely.");
                    break;
                }
            }

            const BOOL isDirectory = [normalizedPath hasSuffix:@"/"] || (fileMode & S_IFMT) == S_IFDIR;
            NSURL* targetURL = extractionURL;
            for (NSString* component in safeComponents)
            {
                targetURL = [targetURL URLByAppendingPathComponent:component isDirectory:NO];
            }

            NSString* basePath = [extractionURL.URLByStandardizingPath.path stringByAppendingString:@"/"];
            NSString* targetPath = targetURL.URLByStandardizingPath.path;
            if (![targetPath hasPrefix:basePath])
            {
                SetImportError(errorMessage, @"The ZIP contains an unsafe file path.");
                break;
            }

            if (isDirectory)
            {
                if (![fileManager createDirectoryAtURL:targetURL
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&fileError])
                {
                    SetImportError(
                        errorMessage,
                        [NSString stringWithFormat:@"Could not create an imported folder: %@",
                                                   fileError.localizedDescription]);
                    break;
                }
                continue;
            }

            if (entry.size > kMaximumEntryBytes || totalBytes > kMaximumArchiveBytes - entry.size)
            {
                SetImportError(errorMessage, @"The ZIP expands beyond the safe import size limit.");
                break;
            }
            totalBytes += entry.size;

            if (![fileManager createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent]
                        withIntermediateDirectories:YES
                                         attributes:nil
                                              error:&fileError])
            {
                SetImportError(
                    errorMessage,
                    [NSString stringWithFormat:@"Could not prepare an imported file: %@",
                                               fileError.localizedDescription]);
                break;
            }

            zip_file_t* input = zip_fopen_index(archive, index, 0);
            if (input == nullptr)
            {
                SetImportError(errorMessage, @"Could not read a file from the ZIP.");
                break;
            }

            int output = open(targetURL.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
            if (output < 0)
            {
                zip_fclose(input);
                SetImportError(errorMessage, @"Could not create a file from the ZIP.");
                break;
            }

            std::array<uint8_t, 64 * 1024> buffer = {};
            zip_uint64_t writtenBytes = 0;
            while (writtenBytes < entry.size)
            {
                const zip_uint64_t remaining = entry.size - writtenBytes;
                const zip_uint64_t requested = std::min<zip_uint64_t>(buffer.size(), remaining);
                const zip_int64_t readBytes = zip_fread(input, buffer.data(), requested);
                if (readBytes <= 0)
                {
                    failed = true;
                    break;
                }

                zip_int64_t offset = 0;
                while (offset < readBytes)
                {
                    const ssize_t result = write(output, buffer.data() + offset, static_cast<size_t>(readBytes - offset));
                    if (result <= 0)
                    {
                        failed = true;
                        break;
                    }
                    offset += result;
                }
                writtenBytes += static_cast<zip_uint64_t>(readBytes);
            }

            close(output);
            zip_fclose(input);
            if (failed || writtenBytes != entry.size)
            {
                SetImportError(errorMessage, @"The ZIP ended unexpectedly while extracting a file.");
                break;
            }

            if (index == 0 || index + 1 == static_cast<zip_uint64_t>(entryCount) || index % 200 == 0)
            {
                updateProgress(
                    [NSString stringWithFormat:@"Extracting ZIP (%llu of %lld)…", index + 1, entryCount]);
            }
        }

        if (zip_close(archive) != 0 && errorMessage != nullptr && *errorMessage == nil)
        {
            SetImportError(errorMessage, @"The ZIP could not be closed after extraction.");
        }

        if (errorMessage != nullptr && *errorMessage != nil)
        {
            [fileManager removeItemAtURL:extractionURL error:nil];
            return nil;
        }
        return extractionURL;
    }

    static NSString* CopyRCT2Directory(
        NSURL* sourceURL, void (^updateProgress)(NSString*), NSString** errorMessage)
    {
        NSFileManager* fileManager = [[NSFileManager alloc] init];
        NSArray<NSString*>* requiredDirectories = @[ @"Data", @"ObjData", @"Scenarios", @"Tracks" ];
        NSMutableDictionary<NSString*, NSURL*>* sourceDirectories = [NSMutableDictionary dictionary];

        NSURL* dataURL = FindChild(fileManager, sourceURL, @"Data", YES);
        NSURL* classicResourcesURL = nil;
        if (ContainsG1(fileManager, dataURL))
        {
            for (NSString* directoryName in requiredDirectories)
            {
                NSURL* child = FindChild(fileManager, sourceURL, directoryName, YES);
                if (child == nil)
                {
                    *errorMessage = [[NSString stringWithFormat:@"The selected folder is missing %@.", directoryName] copy];
                    [fileManager release];
                    return nil;
                }
                sourceDirectories[directoryName] = child;
            }
            NSLog(@"[OpenRCT2Touch] import: validated layout=rct2");
        }
        else
        {
            classicResourcesURL = FindRCTClassicResources(fileManager, sourceURL);
            if (classicResourcesURL == nil)
            {
                if (dataURL != nil)
                {
                    *errorMessage = [@"The selected folder does not contain Data/g1.dat." copy];
                }
                else
                {
                    *errorMessage = [@"The selected folder is not a supported RCT2 or RCT Classic installation. "
                                      "Choose a folder containing Data/g1.dat, Assets/g1.dat, or the RCT Classic macOS app."
                        copy];
                }
                [fileManager release];
                return nil;
            }
            NSLog(@"[OpenRCT2Touch] import: validated layout=rct-classic");
        }

        NSURL* documentsURL = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL* destinationURL = [documentsURL URLByAppendingPathComponent:@"rct2" isDirectory:YES];
        NSURL* temporaryURL = [documentsURL
            URLByAppendingPathComponent:[NSString stringWithFormat:@"rct2.importing-%@", NSUUID.UUID.UUIDString]
                             isDirectory:YES];
        NSURL* backupURL = [documentsURL
            URLByAppendingPathComponent:[NSString stringWithFormat:@"rct2.previous-%@", NSUUID.UUID.UUIDString]
                             isDirectory:YES];

        NSError* error = nil;
        if (![fileManager createDirectoryAtURL:temporaryURL withIntermediateDirectories:YES attributes:nil error:&error])
        {
            *errorMessage = [[NSString stringWithFormat:@"Could not prepare the import: %@", error.localizedDescription] copy];
            [fileManager release];
            return nil;
        }

        if (classicResourcesURL != nil)
        {
            updateProgress(@"Copying RCT Classic assets (1 of 1)…");
            NSURL* targetURL = [temporaryURL URLByAppendingPathComponent:@"Assets" isDirectory:YES];
            if (![fileManager copyItemAtURL:classicResourcesURL toURL:targetURL error:&error])
            {
                [fileManager removeItemAtURL:temporaryURL error:nil];
                *errorMessage = [[NSString stringWithFormat:@"Could not copy RCT Classic assets: %@",
                                                            error.localizedDescription]
                    copy];
                [fileManager release];
                return nil;
            }
        }
        else
        {
            NSUInteger completed = 0;
            for (NSString* directoryName in requiredDirectories)
            {
                updateProgress(
                    [NSString stringWithFormat:@"Copying %@ (%lu of %lu)…", directoryName,
                                               static_cast<unsigned long>(completed + 1),
                                               static_cast<unsigned long>(requiredDirectories.count)]);
                NSURL* targetURL = [temporaryURL URLByAppendingPathComponent:directoryName isDirectory:YES];
                if (![fileManager copyItemAtURL:sourceDirectories[directoryName] toURL:targetURL error:&error])
                {
                    [fileManager removeItemAtURL:temporaryURL error:nil];
                    *errorMessage = [[NSString stringWithFormat:@"Could not copy %@: %@", directoryName,
                                                                error.localizedDescription]
                        copy];
                    [fileManager release];
                    return nil;
                }
                completed++;
            }

            NSURL* executableURL = FindChild(fileManager, sourceURL, @"RCT2.EXE", NO);
            if (executableURL != nil)
            {
                NSURL* targetURL = [temporaryURL URLByAppendingPathComponent:@"RCT2.EXE" isDirectory:NO];
                if (![fileManager copyItemAtURL:executableURL toURL:targetURL error:&error])
                {
                    [fileManager removeItemAtURL:temporaryURL error:nil];
                    *errorMessage = [[NSString stringWithFormat:@"Could not copy RCT2.EXE: %@",
                                                                error.localizedDescription]
                        copy];
                    [fileManager release];
                    return nil;
                }
            }
        }

        BOOL movedExistingDestination = NO;
        if ([fileManager fileExistsAtPath:destinationURL.path])
        {
            if (![fileManager moveItemAtURL:destinationURL toURL:backupURL error:&error])
            {
                [fileManager removeItemAtURL:temporaryURL error:nil];
                *errorMessage = [[NSString stringWithFormat:@"Could not preserve the previous import: %@",
                                                            error.localizedDescription]
                    copy];
                [fileManager release];
                return nil;
            }
            movedExistingDestination = YES;
        }

        if (![fileManager moveItemAtURL:temporaryURL toURL:destinationURL error:&error])
        {
            if (movedExistingDestination)
            {
                [fileManager moveItemAtURL:backupURL toURL:destinationURL error:nil];
            }
            [fileManager removeItemAtURL:temporaryURL error:nil];
            *errorMessage = [[NSString stringWithFormat:@"Could not finish the import: %@", error.localizedDescription]
                copy];
            [fileManager release];
            return nil;
        }

        if (movedExistingDestination)
        {
            [fileManager removeItemAtURL:backupURL error:nil];
        }

        NSString* result = [destinationURL.path copy];
        [fileManager release];
        return result;
    }

    static NSURL* PickImportSource(UIWindow* presentationWindow)
    {
        UIViewController* presenter = GetPresenter(presentationWindow);
        if (presenter == nil)
        {
            return nil;
        }

        ImportPanelSelection selection = { NO, nil };
        void* session = OpenRCT2TouchPresentRCT2ImportPanel(
            static_cast<void*>(presenter), static_cast<void*>(&selection), HandleImportPanelSelection);
        if (session == nullptr)
        {
            NSLog(@"[OpenRCT2Touch] import: SwiftUI panel presentation failed");
            return nil;
        }

        NSLog(@"[OpenRCT2Touch] import: SwiftUI ZIP/folder panel presented");
        while (!selection.finished)
        {
            PumpMainRunLoop();
        }
        OpenRCT2TouchReleaseRCT2ImportPanel(session);
        return [selection.selectedURL autorelease];
    }

    static void ShowImportError(SDL_Window* window, NSString* message)
    {
        NSLog(@"[OpenRCT2Touch] import: failed: %@", message);
        SDL_ShowSimpleMessageBox(
            SDL_MESSAGEBOX_ERROR, "OpenRCT2 Touch Import", message.UTF8String, window);
    }

    static std::string ImportSource(SDL_Window* window, UIWindow* presentationWindow, NSURL* sourceURL)
    {
        UIViewController* presenter = GetPresenter(presentationWindow);
        if (presenter == nil)
        {
            return {};
        }

        UIAlertController* progress = [UIAlertController
            alertControllerWithTitle:@"Importing RollerCoaster Tycoon 2"
                             message:@"Preparing your files…"
                      preferredStyle:UIAlertControllerStyleAlert];
        [presenter presentViewController:progress animated:YES completion:nil];

        __block NSString* importedPath = nil;
        __block NSString* errorMessage = nil;
        __block BOOL finished = NO;
        BOOL hasSecurityScope = [sourceURL startAccessingSecurityScopedResource];
        NSLog(@"[OpenRCT2Touch] import: selected=%@ security_scope=%d", sourceURL.lastPathComponent, hasSecurityScope);

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool
            {
                NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
                __block NSString* coordinatedResult = nil;
                __block NSString* coordinatedErrorMessage = nil;
                NSError* coordinationError = nil;
                [coordinator coordinateReadingItemAtURL:sourceURL
                                                 options:NSFileCoordinatorReadingWithoutChanges
                                                   error:&coordinationError
                                              byAccessor:^(NSURL* coordinatedURL) {
                                                  void (^updateProgress)(NSString*) = ^(NSString* status) {
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          progress.message = status;
                                                      });
                                                  };

                                                  NSNumber* isDirectory = nil;
                                                  [coordinatedURL getResourceValue:&isDirectory
                                                                           forKey:NSURLIsDirectoryKey
                                                                            error:nil];
                                                  if (isDirectory.boolValue)
                                                  {
                                                      coordinatedResult = CopyRCT2Directory(
                                                          coordinatedURL, updateProgress, &coordinatedErrorMessage);
                                                      return;
                                                  }

                                                  if ([coordinatedURL.pathExtension caseInsensitiveCompare:@"zip"]
                                                      != NSOrderedSame)
                                                  {
                                                      coordinatedErrorMessage = [@"Choose an RCT2 folder or a ZIP file." copy];
                                                      return;
                                                  }

                                                  NSFileManager* fileManager = [[NSFileManager alloc] init];
                                                  updateProgress(@"Inspecting ZIP…");
                                                  NSURL* extractedURL = ExtractZipArchive(
                                                      fileManager, coordinatedURL, updateProgress, &coordinatedErrorMessage);
                                                  if (extractedURL != nil)
                                                  {
                                                      NSURL* importRoot = FindSupportedImportRoot(fileManager, extractedURL);
                                                      if (importRoot == nil)
                                                      {
                                                          coordinatedErrorMessage = [@"The ZIP does not contain a supported RCT2 or RCT Classic installation. Include Data/g1.dat and the ObjData, Scenarios, and Tracks folders." copy];
                                                      }
                                                      else
                                                      {
                                                          coordinatedResult = CopyRCT2Directory(
                                                              importRoot, updateProgress, &coordinatedErrorMessage);
                                                      }
                                                      [fileManager removeItemAtURL:extractedURL error:nil];
                                                  }
                                                  [fileManager release];
                                              }];

                if (coordinationError != nil && coordinatedErrorMessage == nil)
                {
                    coordinatedErrorMessage = [[NSString
                        stringWithFormat:@"Could not access the selected folder: %@", coordinationError.localizedDescription]
                        copy];
                }
                [coordinator release];

                dispatch_async(dispatch_get_main_queue(), ^{
                    importedPath = coordinatedResult;
                    errorMessage = coordinatedErrorMessage;
                    finished = YES;
                });
            }
        });

        while (!finished)
        {
            PumpMainRunLoop();
        }
        if (hasSecurityScope)
        {
            [sourceURL stopAccessingSecurityScopedResource];
        }

        __block BOOL dismissed = NO;
        [progress dismissViewControllerAnimated:YES
                                     completion:^{
                                         dismissed = YES;
                                     }];
        while (!dismissed)
        {
            PumpMainRunLoop();
        }

        if (importedPath == nil)
        {
            ShowImportError(window, errorMessage == nil ? @"The import failed." : errorMessage);
            [errorMessage release];
            return {};
        }

        std::string result(importedPath.fileSystemRepresentation);
        NSLog(@"[OpenRCT2Touch] import: completed destination=Documents/rct2");
        [importedPath release];
        [errorMessage release];
        return result;
    }

    std::string ShowRCT2DirectoryImporter(SDL_Window* window, const std::string& title)
    {
        if (![NSThread isMainThread])
        {
            NSLog(@"[OpenRCT2Touch] import: document picker requested off the main thread");
            return {};
        }

        @autoreleasepool
        {
            ImportPresentationContext presentationContext = CreatePresentationContext(window);
            if (presentationContext.window == nil)
            {
                NSLog(@"[OpenRCT2Touch] import: cancelled because no presenter is available");
                return {};
            }

            (void) title;
            while (true)
            {
                NSURL* sourceURL = PickImportSource(presentationContext.window);
                if (sourceURL == nil)
                {
                    NSLog(@"[OpenRCT2Touch] import: cancelled");
                    DestroyPresentationContext(&presentationContext);
                    return {};
                }

                auto result = ImportSource(window, presentationContext.window, sourceURL);
                if (!result.empty())
                {
                    DestroyPresentationContext(&presentationContext);
                    return result;
                }
            }
        }
    }
} // namespace OpenRCT2::Ui
