/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChromeParkState.iOS.h"
#include "NativeScenarioPicker.iOS.h"
#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <openrct2/Context.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/scenes/SceneManager.h>
    #include <openrct2/ui/WindowManager.h>
    #include <openrct2-ui/interface/Window.h>

namespace OpenRCT2::Ui
{
    bool NativeChromeParkIsOpen()
    {
        auto* context = OpenRCT2::GetContext();
        if (context == nullptr)
        {
            return false;
        }

        auto* sceneMgr = context->GetSceneManager();
        if (sceneMgr == nullptr || sceneMgr->getActiveScene() == nullptr
            || sceneMgr->getActiveScene() != sceneMgr->getGameScene())
        {
            return false;
        }

        if (gLegacyScene != LegacyScene::playing || isInTrackDesignerOrManager())
        {
            return false;
        }

        auto* windowMgr = GetWindowManager();
        if (windowMgr == nullptr)
        {
            return false;
        }
        if (windowMgr->FindByClass(WindowClass::progressWindow) != nullptr
            || windowMgr->FindByClass(WindowClass::titleMenu) != nullptr
            || windowMgr->FindByClass(WindowClass::titleLogo) != nullptr
            || windowMgr->FindByClass(WindowClass::titleExit) != nullptr
            || windowMgr->FindByClass(WindowClass::titleOptions) != nullptr
            || windowMgr->FindByClass(WindowClass::scenarioSelect) != nullptr || NativeScenarioPickerIsOpen())
        {
            return false;
        }

        return true;
    }

    NativeChromeParkStateSnapshot NativeChromeCaptureParkStateSnapshot()
    {
        NativeChromeParkStateSnapshot snapshot{};
        snapshot.Open = NativeChromeParkIsOpen() ? 1 : 0;
        if (snapshot.Open == 0)
        {
            return snapshot;
        }

        snapshot.Paused = GameIsPaused() ? 1 : 0;
        snapshot.Speed = gGameSpeed;

        auto* mainWindow = WindowGetMain();
        if (mainWindow != nullptr && mainWindow->viewport != nullptr)
        {
            snapshot.ViewportFlags = mainWindow->viewport->flags;
        }

        const auto& gameState = getGameState();
        snapshot.Cash = gameState.park.cash;
        snapshot.Guests = gameState.park.numGuestsInPark;
        snapshot.Rating = gameState.park.rating;
        snapshot.Month = gameState.date.GetMonth();
        snapshot.Day = gameState.date.GetDay();
        return snapshot;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
