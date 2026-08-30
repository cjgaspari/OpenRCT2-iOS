/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeScenarioPicker.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include "NativeChrome.iOS.h"
    #include "chrome/ParkChromeActions.h"

    #include <openrct2-ui/UiStringIds.h>
    #include <openrct2-ui/interface/Objective.h>
    #include <openrct2-ui/windows/Windows.h>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/FileClassifier.h>
    #include <openrct2/Game.h>
    #include <openrct2/ParkImporter.h>
    #include <openrct2/audio/Audio.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/core/BackgroundWorker.hpp>
    #include <openrct2/core/FileStream.h>
    #include <openrct2/core/Json.hpp>
    #include <openrct2/drawing/Drawing.h>
    #include <openrct2/localisation/Formatter.h>
    #include <openrct2/localisation/Formatting.h>
    #include <openrct2/localisation/StringIds.h>
    #include <openrct2/object/ObjectManager.h>
    #include <openrct2/object/ScenarioMetaObject.h>
    #include <openrct2/park/ParkPreview.h>
    #include <openrct2/rct12/RCT12.h>
    #include <openrct2/scenario/Scenario.h>
    #include <openrct2/scenario/ScenarioCategory.h>
    #include <openrct2/scenario/ScenarioObjective.h>
    #include <openrct2/scenario/ScenarioRepository.h>
    #include <openrct2/scenario/ScenarioSources.h>

    #include <algorithm>
    #include <cstddef>
    #include <iterator>
    #include <optional>
    #include <string>
    #include <utility>
    #include <vector>

namespace OpenRCT2::Ui
{
    namespace
    {
        constexpr int32_t kInitialNumUnlockedScenarios = 5;
        constexpr int32_t kSourceCount = 10;

        constexpr StringId kScenarioOriginStringIds[] = {
            STR_SCENARIO_CATEGORY_RCT1,
            STR_SCENARIO_CATEGORY_RCT1_AA,
            STR_SCENARIO_CATEGORY_RCT1_LL,
            STR_SCENARIO_CATEGORY_RCT2,
            STR_SCENARIO_CATEGORY_RCT2_WW,
            STR_SCENARIO_CATEGORY_RCT2_TT,
            STR_SCENARIO_CATEGORY_UCES,
            STR_SCENARIO_CATEGORY_REAL_PARKS,
            STR_SCENARIO_CATEGORY_EXTRAS_PARKS,
            STR_SCENARIO_CATEGORY_OTHER_PARKS,
        };

        struct PickerEntry
        {
            int32_t id{};
            std::string path;
            std::string internalName;
            bool locked{};
        };

        struct ScenarioRow
        {
            int32_t id{};
            const ScenarioIndexEntry* scenario{};
            bool locked{};
        };

        bool gPickerOpen = false;
        int32_t gPreviewScenarioID = -1;
        std::string gSnapshotJSON;
        std::function<void(std::string_view)> gSelectionCallback;
        std::vector<PickerEntry> gEntries;
        BackgroundWorker::Job gPreviewLoadJob;

        std::string PlainText(std::string_view text)
        {
            return RCT12RemoveFormattingUTF8(text);
        }

        std::string StringFromId(StringId stringId)
        {
            return PlainText(FormatStringIDLegacy(stringId, nullptr));
        }

        std::string ObjectiveText(const ScenarioIndexEntry& scenario)
        {
            const auto objectiveIndex = EnumValue(scenario.ObjectiveType);
            if (objectiveIndex >= std::size(kObjectiveNames))
            {
                return {};
            }

            Scenario::Objective objective = {
                .Type = scenario.ObjectiveType,
                .Year = scenario.ObjectiveArg1,
                .NumGuests = static_cast<uint16_t>(scenario.ObjectiveArg3),
                .Currency = scenario.ObjectiveArg2,
            };
            Formatter ft;
            formatObjective(ft, objective);
            return PlainText(FormatStringIDLegacy(kObjectiveNames[objectiveIndex], ft.Data()));
        }

        std::string CompanyValueText(money64 companyValue)
        {
            Formatter ft;
            ft.Add<money64>(companyValue);
            return PlainText(FormatStringIDLegacy(STR_CURRENCY_FORMAT, ft.Data()));
        }

        std::vector<ScenarioRow> BuildRowsForSource(int32_t sourceID)
        {
            std::vector<ScenarioRow> rows;
            const bool lockingEnabled = Config::Get().general.scenarioUnlockingEnabled && sourceID < 6;
            int32_t numUnlocks = kInitialNumUnlockedScenarios;
            uint32_t rct1CompletedScenarios = 0;
            std::optional<size_t> megaParkIndex;

            const auto scenarioCount = ScenarioRepositoryGetCount();
            for (size_t index = 0; index < scenarioCount; ++index)
            {
                const auto* scenario = ScenarioRepositoryGetByIndex(index);
                if (scenario == nullptr || EnumValue(scenario->SourceGame) != sourceID)
                {
                    continue;
                }

                bool locked = false;
                if (lockingEnabled)
                {
                    locked = numUnlocks <= 0;
                    if (scenario->Highscore == nullptr)
                    {
                        --numUnlocks;
                    }
                    else if (scenario->ScenarioId < SC_MEGA_PARK)
                    {
                        rct1CompletedScenarios |= 1u << scenario->ScenarioId;
                    }

                    if (scenario->ScenarioId == SC_MEGA_PARK)
                    {
                        megaParkIndex = rows.size();
                    }
                }

                rows.push_back({ static_cast<int32_t>(index), scenario, locked });
            }

            if (megaParkIndex.has_value() && megaParkIndex.value() < rows.size())
            {
                const uint32_t required = (1u << SC_MEGA_PARK) - 1u;
                const bool megaParkLocked = (rct1CompletedScenarios & required) != required;
                rows[megaParkIndex.value()].locked = megaParkLocked;
                if (megaParkLocked && Config::Get().general.scenarioHideMegaPark)
                {
                    rows.erase(rows.begin() + static_cast<std::ptrdiff_t>(megaParkIndex.value()));
                }
            }

            return rows;
        }

        json_t ScenarioJSON(const ScenarioRow& row)
        {
            const auto& scenario = *row.scenario;
            json_t result = {
                { "id", row.id },
                { "sourceID", EnumValue(scenario.SourceGame) },
                { "categoryID", EnumValue(scenario.Category) },
                { "categoryTitle", StringFromId(Scenario::kScenarioCategoryStringIds[EnumValue(scenario.Category)]) },
                { "title", scenario.Name },
                { "details", scenario.Details },
                { "objective", ObjectiveText(scenario) },
                { "isLocked", row.locked },
            };

            if (scenario.Highscore != nullptr)
            {
                result["completedBy"] = scenario.Highscore->name.empty() ? "???" : scenario.Highscore->name;
                result["companyValue"] = CompanyValueText(scenario.Highscore->company_value);
            }
            else
            {
                result["completedBy"] = nullptr;
                result["companyValue"] = nullptr;
            }

            if (Config::Get().general.debuggingTools)
            {
                result["debugPath"] = scenario.Path;
            }
            else
            {
                result["debugPath"] = nullptr;
            }
            return result;
        }

        std::string BuildSnapshotJSON()
        {
            json_t sources = json_t::array();
            json_t scenarios = json_t::array();
            gEntries.clear();

            int32_t firstSource = -1;
            for (int32_t sourceID = 0; sourceID < kSourceCount; ++sourceID)
            {
                auto rows = BuildRowsForSource(sourceID);
                if (rows.empty())
                {
                    continue;
                }

                if (firstSource < 0)
                {
                    firstSource = sourceID;
                }
                const auto sourceTitle = StringFromId(kScenarioOriginStringIds[sourceID]);
                sources.push_back({
                    { "id", sourceID },
                    { "title", sourceTitle },
                    { "shortTitle", sourceTitle },
                    { "scenarioCount", rows.size() },
                    { "showsCategories", sourceID != EnumValue(ScenarioSource::real) },
                });

                for (const auto& row : rows)
                {
                    scenarios.push_back(ScenarioJSON(row));
                    gEntries.push_back({ row.id, row.scenario->Path, row.scenario->InternalName, row.locked });
                }
            }

            int32_t selectedSource = Config::Get().interface.scenarioSelectLastTab;
            const bool selectedSourceExists = std::any_of(
                sources.begin(), sources.end(), [selectedSource](const auto& source) {
                    return source.at("id").template get<int32_t>() == selectedSource;
                });
            if (!selectedSourceExists)
            {
                selectedSource = firstSource;
            }

            json_t snapshot = {
                { "title", StringFromId(STR_SELECT_SCENARIO) },
                { "lockedTitle", StringFromId(STR_SCENARIO_LOCKED) },
                { "lockedMessage", StringFromId(STR_SCENARIO_LOCKED_DESC) },
                { "selectedSourceID", selectedSource },
                { "sources", std::move(sources) },
                { "scenarios", std::move(scenarios) },
            };
            return snapshot.dump();
        }

        const PickerEntry* FindEntry(int32_t scenarioID)
        {
            const auto it = std::find_if(gEntries.begin(), gEntries.end(), [scenarioID](const auto& entry) {
                return entry.id == scenarioID;
            });
            return it == gEntries.end() ? nullptr : &*it;
        }

        void PublishPreview(int32_t scenarioID, const ParkPreview& preview)
        {
            if (!gPickerOpen || scenarioID != gPreviewScenarioID)
            {
                return;
            }

            const auto targetType = Config::Get().interface.scenarioPreviewScreenshots ? PreviewImageType::screenshot
                                                                                       : PreviewImageType::miniMap;
            const PreviewImage* image = nullptr;
            for (const auto& candidate : preview.images)
            {
                if (candidate.type == targetType)
                {
                    image = &candidate;
                    break;
                }
            }

            if (image == nullptr || image->width == 0 || image->height == 0)
            {
                NativeChromeScenarioPickerSetPreview(scenarioID, nullptr, 0, 0, 0);
                return;
            }

            const size_t pixelCount = static_cast<size_t>(image->width) * image->height;
            std::vector<uint8_t> rgba(pixelCount * 4);
            for (size_t index = 0; index < pixelCount; ++index)
            {
                const auto paletteIndex = static_cast<uint8_t>(image->pixels[index]);
                const auto& colour = gPalette[paletteIndex];
                rgba[(index * 4) + 0] = colour.red;
                rgba[(index * 4) + 1] = colour.green;
                rgba[(index * 4) + 2] = colour.blue;
                rgba[(index * 4) + 3] = 0xFF;
            }
            NativeChromeScenarioPickerSetPreview(
                scenarioID, rgba.data(), rgba.size(), image->width, image->height);
        }

        ParkPreview LoadMetadataPreview(const PickerEntry& entry)
        {
            SourceDescriptor source{};
            if (!ScenarioSources::TryGetByName(entry.internalName, &source))
            {
                return {};
            }

            auto& objectManager = GetContext()->GetObjectManager();
            auto object = objectManager.LoadTempObject(source.textObjectId, true);
            if (object == nullptr)
            {
                return {};
            }

            auto& scenarioMeta = reinterpret_cast<ScenarioMetaObject&>(*object);
            scenarioMeta.Load();
            ParkPreview preview{};
            preview.images.push_back(scenarioMeta.GetMiniMapImage());
            preview.images.push_back(scenarioMeta.GetPreviewImage());
            scenarioMeta.Unload();
            return preview;
        }

        void RequestPreview(int32_t scenarioID)
        {
            const auto* entry = FindEntry(scenarioID);
            if (entry == nullptr || entry->locked)
            {
                return;
            }

            gPreviewScenarioID = scenarioID;
            if (gPreviewLoadJob.isValid())
            {
                gPreviewLoadJob.cancel();
            }
            NativeChromeScenarioPickerSetPreviewLoading(scenarioID, true);

            ClassifiedFileInfo info;
            if (TryClassifyFile(entry->path, &info) && info.Type == FileType::park)
            {
                const auto path = entry->path;
                auto& worker = GetContext()->GetBackgroundWorker();
                gPreviewLoadJob = worker.addJob(
                    [path]() {
                        try
                        {
                            auto stream = FileStream(path, FileMode::open);
                            auto& objectRepository = GetContext()->GetObjectRepository();
                            auto importer = ParkImporter::CreateParkFile(objectRepository);
                            importer->LoadFromStream(&stream, false, true, path.c_str());
                            return importer->GetParkPreview();
                        }
                        catch (const std::exception& error)
                        {
                            LOG_ERROR("Could not get native scenario preview for \"%s\" due to %s", path.c_str(), error.what());
                            return ParkPreview{};
                        }
                    },
                    [scenarioID](const ParkPreview preview) { PublishPreview(scenarioID, preview); });
                return;
            }

            PublishPreview(scenarioID, LoadMetadataPreview(*entry));
        }

        void ClosePicker()
        {
            if (gPreviewLoadJob.isValid())
            {
                gPreviewLoadJob.cancel();
            }
            gPickerOpen = false;
            gPreviewScenarioID = -1;
            gSnapshotJSON.clear();
            gEntries.clear();
            gSelectionCallback = {};
            NativeChromeScenarioPickerDismiss();
        }

        void StartScenario(int32_t scenarioID)
        {
            const auto* entry = FindEntry(scenarioID);
            if (entry == nullptr || entry->locked || !gSelectionCallback)
            {
                return;
            }

            const auto path = entry->path;
            auto callback = std::move(gSelectionCallback);
            Audio::Play(Audio::SoundId::click1, 0, ContextGetWidth() / 2);
            gFirstTimeSaving = true;
            ClosePicker();
            callback(path);
        }
    } // namespace

    WindowBase* NativeScenarioPickerOpen(std::function<void(std::string_view)> callback)
    {
        if (gPickerOpen)
        {
            NativeChromeScenarioPickerPresent(gSnapshotJSON);
            return nullptr;
        }

        ScenarioRepositoryScan();
        gSelectionCallback = std::move(callback);
        gSnapshotJSON = BuildSnapshotJSON();
        gPickerOpen = true;
        NativeChromeScenarioPickerPresent(gSnapshotJSON);
        return nullptr;
    }

    bool NativeScenarioPickerIsOpen()
    {
        return gPickerOpen;
    }

    bool NativeScenarioPickerHandleAction(int32_t code, int32_t extra)
    {
        switch (code)
        {
            case kNativeChromeScenarioStart:
                if (gPickerOpen)
                {
                    StartScenario(extra);
                }
                return true;
            case kNativeChromeScenarioCancel:
                if (gPickerOpen)
                {
                    ClosePicker();
                }
                return true;
            case kNativeChromeScenarioSource:
                if (gPickerOpen && extra >= 0 && extra < kSourceCount)
                {
                    Config::Get().interface.scenarioSelectLastTab = extra;
                    Config::Save();
                }
                return true;
            case kNativeChromeScenarioPreview:
                if (gPickerOpen)
                {
                    RequestPreview(extra);
                }
                return true;
            default:
                return false;
        }
    }

    void NativeScenarioPickerRefreshPresentation()
    {
        if (gPickerOpen)
        {
            NativeChromeScenarioPickerPresent(gSnapshotJSON);
        }
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
