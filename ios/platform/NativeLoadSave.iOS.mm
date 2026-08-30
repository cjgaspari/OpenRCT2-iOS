/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeLoadSave.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "NativeChrome.iOS.h"
    #include "chrome/ParkChromeActions.h"

    #include <openrct2-ui/interface/FileBrowser.h>
    #include <openrct2/Context.h>
    #include <openrct2/Game.h>
    #include <openrct2/audio/Audio.h>
    #include <openrct2/core/FileScanner.h>
    #include <openrct2/core/Json.hpp>
    #include <openrct2/core/Path.hpp>
    #include <openrct2/core/String.hpp>
    #include <openrct2/interface/WindowTypes.h>
    #include <openrct2/platform/Platform.h>
    #include <openrct2/scenario/Scenario.h>

    #include <algorithm>
    #include <cstdio>
    #include <string>
    #include <vector>

using namespace OpenRCT2::Ui::FileBrowser;

namespace OpenRCT2::Ui
{
    namespace
    {
        constexpr uint64_t kKibiByte = 1024;
        constexpr uint64_t kMebiByte = kKibiByte * 1024;

        bool gOpen = false;
        bool gIsSave = false;
        LoadSaveAction gAction{};
        LoadSaveType gType{};
        TrackDesign* gTrackDesign = nullptr;
        u8string gDirectory;
        u8string gExtension;
        std::vector<u8string> gPaths;
        std::string gSnapshotJSON;

        std::string HumanFileSize(uint64_t bytes)
        {
            char buffer[32];
            if (bytes >= kMebiByte)
            {
                std::snprintf(buffer, sizeof(buffer), "%.1f MB", static_cast<double>(bytes) / kMebiByte);
            }
            else if (bytes >= kKibiByte)
            {
                std::snprintf(buffer, sizeof(buffer), "%llu KB", static_cast<unsigned long long>(bytes / kKibiByte));
            }
            else
            {
                std::snprintf(buffer, sizeof(buffer), "%llu B", static_cast<unsigned long long>(bytes));
            }
            return buffer;
        }

        std::vector<LoadSaveListItem> ScanFiles(const u8string& directory, std::string_view extensionPattern)
        {
            std::vector<LoadSaveListItem> items;
            for (const u8string_view extToken : String::split(extensionPattern, ";"))
            {
                const u8string filter = Path::Combine(directory, extToken);
                auto scanner = Path::ScanDirectory(filter, false);
                while (scanner->Next())
                {
                    LoadSaveListItem item;
                    item.path = scanner->GetPath();
                    item.type = FileType::file;
                    item.dateModified = Platform::FileGetModifiedTime(item.path.c_str());
                    item.dateFormatted = Platform::FormatShortDate(item.dateModified);
                    item.fileSizeBytes = Platform::GetFileSize(item.path.c_str());
                    item.loaded = item.path == gCurrentLoadedPath;
                    item.name = Path::GetFileNameWithoutExtension(item.path);
                    items.push_back(std::move(item));
                }
            }
            std::sort(items.begin(), items.end(), ListItemSort);
            return items;
        }

        u8string DefaultSaveName()
        {
            if (!gScenarioSavePath.empty())
            {
                auto name = Path::GetFileNameWithoutExtension(gScenarioSavePath);
                if (!name.empty())
                {
                    return name;
                }
            }
            return u8"park";
        }

        std::string BuildSnapshotJSON()
        {
            gPaths.clear();
            json_t files = json_t::array();

            const auto items = ScanFiles(gDirectory, GetFilterPatternByType(gType, gIsSave, gTrackDesign));
            int32_t index = 0;
            for (const auto& item : items)
            {
                std::string detail = item.dateFormatted;
                if (!detail.empty())
                {
                    detail += "  \u00B7  ";
                }
                detail += HumanFileSize(item.fileSizeBytes);

                files.push_back({
                    { "id", index },
                    { "name", item.name },
                    { "detail", detail },
                    { "isLoaded", item.loaded },
                });
                gPaths.push_back(item.path);
                ++index;
            }

            json_t snapshot = {
                { "isSave", gIsSave },
                { "title", gIsSave ? "Save Park" : "Load Park" },
                { "defaultName", DefaultSaveName() },
                { "emptyMessage", gIsSave ? "No saved parks yet. Name your park below and tap Save."
                                          : "No saved parks were found." },
                { "files", std::move(files) },
            };
            return snapshot.dump();
        }

        void ClosePicker()
        {
            gOpen = false;
            gPaths.clear();
            gSnapshotJSON.clear();
            NativeChromeLoadSaveDismiss();
        }

        void CommitPath(const u8string& path)
        {
            Audio::Play(Audio::SoundId::click1, 0, ContextGetWidth() / 2);
            const auto action = gAction;
            const auto type = gType;
            auto* trackDesign = gTrackDesign;
            ClosePicker();
            Select(path.c_str(), action, type, trackDesign);
            UnregisterJSCallback();
        }

        void SelectEntry(int32_t index)
        {
            if (index < 0 || static_cast<size_t>(index) >= gPaths.size())
            {
                return;
            }
            CommitPath(gPaths[static_cast<size_t>(index)]);
        }

        void CommitTypedName()
        {
            char buffer[512] = { 0 };
            if (!NativeChromeLoadSaveCopyPendingName(buffer, sizeof(buffer)))
            {
                return;
            }
            u8string name = String::trim(buffer);
            if (name.empty())
            {
                return;
            }
            const auto path = Path::Combine(gDirectory, Path::WithExtension(name, gExtension));
            CommitPath(path);
        }

        void Cancel()
        {
            InvokeCallback(ModalResult::cancel, "");
            UnregisterJSCallback();
            ClosePicker();
        }
    } // namespace

    bool NativeLoadSaveOpen(
        LoadSaveAction action, LoadSaveType type, std::string_view defaultPath, NativeLoadSaveCallback callback,
        bool isJsCallback, TrackDesign* trackDesign)
    {
        (void)defaultPath;
        gAction = action;
        gType = type;
        gTrackDesign = trackDesign;
        gIsSave = action == LoadSaveAction::save;
        gDirectory = GetDir(type);
        gExtension = RemovePatternWildcard(String::split(GetFilterPatternByType(type, gIsSave, trackDesign), ";").front());
        if (gExtension.empty())
        {
            gExtension = u8".park";
        }

        RegisterCallback(std::move(callback), isJsCallback);
        gSnapshotJSON = BuildSnapshotJSON();
        gOpen = true;
        NativeChromeLoadSavePresent(gSnapshotJSON);
        return true;
    }

    bool NativeLoadSaveIsOpen()
    {
        return gOpen;
    }

    bool NativeLoadSaveHandleAction(int32_t code, int32_t extra)
    {
        switch (code)
        {
            case kNativeChromeLoadSaveSelect:
                if (gOpen)
                {
                    SelectEntry(extra);
                }
                return true;
            case kNativeChromeLoadSaveCommit:
                if (gOpen && gIsSave)
                {
                    CommitTypedName();
                }
                return true;
            case kNativeChromeLoadSaveCancel:
                if (gOpen)
                {
                    Cancel();
                }
                return true;
            default:
                return false;
        }
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
