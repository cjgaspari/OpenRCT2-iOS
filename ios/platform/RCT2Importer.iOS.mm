/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "RCT2Importer.iOS.h"

#include <SDL.h>
#include <SDL_syswm.h>
#include <UIKit/UIKit.h>

@interface OpenRCT2TouchDirectoryPickerDelegate : NSObject <UIDocumentPickerDelegate>
{
@public
    BOOL finished;
    BOOL dismissed;
    NSURL* selectedURL;
}
@end

@implementation OpenRCT2TouchDirectoryPickerDelegate

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        finished = NO;
        dismissed = NO;
        selectedURL = nil;
    }
    return self;
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    selectedURL = [urls.firstObject retain];
    finished = YES;
    [controller dismissViewControllerAnimated:YES
                                    completion:^{
                                        dismissed = YES;
                                    }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    finished = YES;
    [controller dismissViewControllerAnimated:YES
                                    completion:^{
                                        dismissed = YES;
                                    }];
}

- (void)dealloc
{
    [selectedURL release];
    [super dealloc];
}

@end

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

    static UIWindow* GetActiveWindow(SDL_Window* window)
    {
        if (window != nullptr)
        {
            SDL_SysWMinfo windowInfo = {};
            SDL_VERSION(&windowInfo.version);
            if (SDL_GetWindowWMInfo(window, &windowInfo) == SDL_TRUE && windowInfo.subsystem == SDL_SYSWM_UIKIT
                && windowInfo.info.uikit.window != nil)
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
                if (candidate.isKeyWindow)
                {
                    return candidate;
                }
                if (!candidate.hidden && candidate.rootViewController != nil)
                {
                    fallbackWindow = candidate;
                }
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
            NSLog(@"[OpenRCT2Touch] import: using existing presenter window");
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

    static NSString* CopyRCT2Directory(
        NSURL* sourceURL, void (^updateProgress)(NSString*), NSString** errorMessage)
    {
        NSFileManager* fileManager = [[NSFileManager alloc] init];
        NSArray<NSString*>* requiredDirectories = @[ @"Data", @"ObjData", @"Scenarios", @"Tracks" ];
        NSMutableDictionary<NSString*, NSURL*>* sourceDirectories = [NSMutableDictionary dictionary];

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

        NSURL* dataURL = sourceDirectories[@"Data"];
        if (FindChild(fileManager, dataURL, @"g1.dat", NO) == nil)
        {
            *errorMessage = [@"The selected folder does not contain Data/g1.dat." copy];
            [fileManager release];
            return nil;
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
                *errorMessage = [[NSString stringWithFormat:@"Could not copy RCT2.EXE: %@", error.localizedDescription]
                    copy];
                [fileManager release];
                return nil;
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

    static NSURL* PickDirectory(UIWindow* presentationWindow, NSString* title)
    {
        UIViewController* presenter = GetPresenter(presentationWindow);
        if (presenter == nil)
        {
            return nil;
        }

        OpenRCT2TouchDirectoryPickerDelegate* delegate = [[OpenRCT2TouchDirectoryPickerDelegate alloc] init];
        UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
            initWithDocumentTypes:@[ @"public.folder" ]
                           inMode:UIDocumentPickerModeOpen];
        picker.delegate = delegate;
        picker.allowsMultipleSelection = NO;
        picker.shouldShowFileExtensions = YES;
        picker.title = title;

        NSLog(@"[OpenRCT2Touch] import: picker-presented");
        [presenter presentViewController:picker animated:YES completion:nil];
        while (!delegate->finished)
        {
            PumpMainRunLoop();
        }
        while (!delegate->dismissed)
        {
            PumpMainRunLoop();
        }

        NSURL* result = [delegate->selectedURL retain];
        [picker release];
        [delegate release];
        return [result autorelease];
    }

    static void ShowImportError(SDL_Window* window, NSString* message)
    {
        NSLog(@"[OpenRCT2Touch] import: failed: %@", message);
        SDL_ShowSimpleMessageBox(
            SDL_MESSAGEBOX_ERROR, "OpenRCT2 Touch Import", message.UTF8String, window);
    }

    static std::string ImportDirectory(SDL_Window* window, UIWindow* presentationWindow, NSURL* sourceURL)
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
                                                  coordinatedResult = CopyRCT2Directory(
                                                      coordinatedURL,
                                                      ^(NSString* status) {
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              progress.message = status;
                                                          });
                                                      },
                                                      &coordinatedErrorMessage);
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

            NSString* pickerTitle = [NSString stringWithUTF8String:title.c_str()];
            while (true)
            {
                NSURL* sourceURL = PickDirectory(presentationContext.window, pickerTitle);
                if (sourceURL == nil)
                {
                    NSLog(@"[OpenRCT2Touch] import: cancelled");
                    DestroyPresentationContext(&presentationContext);
                    return {};
                }

                auto result = ImportDirectory(window, presentationContext.window, sourceURL);
                if (!result.empty())
                {
                    DestroyPresentationContext(&presentationContext);
                    return result;
                }
            }
        }
    }
} // namespace OpenRCT2::Ui
