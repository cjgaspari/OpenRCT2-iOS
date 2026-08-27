/*****************************************************************************
 * Copyright (c) 2026 OpenRCT2 Touch contributors
 *
 * OpenRCT2 Touch is licensed under the GNU General Public License version 3.
 *****************************************************************************/

#include "NativeChrome.iOS.h"

#include <TargetConditionals.h>

#if TARGET_OS_IOS

    #include <openrct2-ui/interface/Window.h>
    #include <openrct2-ui/windows/Windows.h>

    #include <SDL.h>
    #include <SDL_syswm.h>
    #include <UIKit/UIKit.h>
    #include <cstdint>
    #include <openrct2/Context.h>
    #include <openrct2/Diagnostic.h>
    #include <openrct2/Game.h>
    #include <openrct2/GameState.h>
    #include <openrct2/OpenRCT2.h>
    #include <openrct2/actions/GameActionRunner.h>
    #include <openrct2/actions/general/GameSetSpeedAction.h>
    #include <openrct2/actions/general/PauseToggleAction.h>
    #include <openrct2/Date.h>
    #include <openrct2/interface/Viewport.h>
    #include <openrct2/interface/Window.h>
    #include <openrct2/config/Config.h>
    #include <openrct2/localisation/Currency.h>
    #include <openrct2/network/Network.h>
    #include <openrct2/scenes/SceneManager.h>
    #include <openrct2/ui/WindowManager.h>
    #include <os/log.h>

@class OpenRCT2TouchNativeChrome;
@class OpenRCT2TouchChromeListController;

namespace
{
    constexpr int32_t kNativeChromeBuildNewRide = 1;
    constexpr int32_t kNativeChromeTrees = 2;
    constexpr int32_t kNativeChromePaths = 3;
    constexpr int32_t kNativeChromeLand = 4;
    constexpr int32_t kNativeChromeWater = 5;
    constexpr int32_t kNativeChromeClearScenery = 6;
    constexpr int32_t kNativeChromeRideList = 7;
    constexpr int32_t kNativeChromeParkInformation = 8;
    constexpr int32_t kNativeChromeStaffList = 9;
    constexpr int32_t kNativeChromeGuestList = 10;
    constexpr int32_t kNativeChromeFinances = 11;
    constexpr int32_t kNativeChromeResearch = 12;
    constexpr int32_t kNativeChromeRecentNews = 13;
    constexpr int32_t kNativeChromeMap = 14;
    constexpr int32_t kNativeChromeExtraViewport = 15;
    constexpr int32_t kNativeChromeViewClipping = 16;
    constexpr int32_t kNativeChromeTransparency = 17;
    constexpr int32_t kNativeChromeLoadSave = 18;
    constexpr int32_t kNativeChromeOptions = 19;
    constexpr int32_t kNativeChromeAbout = 20;
    constexpr int32_t kNativeChromeCheats = 21;
    constexpr int32_t kNativeChromeTileInspector = 22;
    constexpr int32_t kNativeChromePause = 23;
    constexpr int32_t kNativeChromeGameSpeed = 24;
    constexpr int32_t kNativeChromeZoomIn = 25;
    constexpr int32_t kNativeChromeZoomOut = 26;
    constexpr int32_t kNativeChromeRotateCW = 27;
    constexpr int32_t kNativeChromeViewUnderground = 28;
    constexpr int32_t kNativeChromeViewSeeThroughRides = 29;
    constexpr int32_t kNativeChromeViewSeeThroughScenery = 30;
    constexpr int32_t kNativeChromeViewGuests = 31;
    constexpr int32_t kNativeChromeViewStaff = 32;
    constexpr int32_t kNativeChromeViewPathIssues = 33;
    constexpr int32_t kNativeChromeViewHeightMarks = 34;

    constexpr int32_t kChromeExtraXor = -1;
    constexpr NSInteger kChromeLayoutCluster = 0;
    constexpr NSInteger kChromeLayoutSheet = 1;
    constexpr NSInteger kChromeListModeOverflow = 0;
    constexpr NSInteger kChromeListModeSheet = 1;
    constexpr NSInteger kSheetTabBuild = 0;
    constexpr NSInteger kSheetTabPark = 1;
    constexpr NSInteger kSheetTabView = 2;
    constexpr NSInteger kSheetTabMore = 3;
    constexpr CGFloat kChromeSideButtonSize = 48.0;
    constexpr CGFloat kChromeRideButtonSize = 56.0;
    constexpr CGFloat kChromeButtonSpacing = 16.0;
    constexpr CGFloat kChromeCameraSpacing = 12.0;
    constexpr CGFloat kChromeHorizontalPadding = 16.0;
    constexpr CGFloat kChromeDockBottomPadding = 8.0;
    constexpr CGFloat kChromeStatusDockGap = 8.0;
    constexpr CGFloat kChromeCompactSheetHeight = 220.0;
    constexpr uint32_t kHeightMarkFlags = OpenRCT2::VIEWPORT_FLAG_LAND_HEIGHTS | OpenRCT2::VIEWPORT_FLAG_TRACK_HEIGHTS
        | OpenRCT2::VIEWPORT_FLAG_PATH_HEIGHTS;

    NSString* const kChromeLayoutDefaultsKey = @"OpenRCT2Touch.parkChromeLayout";
    NSString* const kChromeCompactDetentId = @"openrct2.touch.compactSheet";

    Uint32 gNativeChromeEventType = 0;

    Uint32 EnsureNativeChromeEventType()
    {
        if (gNativeChromeEventType == 0)
        {
            gNativeChromeEventType = SDL_RegisterEvents(1);
        }
        return gNativeChromeEventType;
    }

    UIImage* ChromeSymbol(NSString* name, CGFloat pointSize)
    {
        UIImageSymbolConfiguration* configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize
                                                                                                     weight:UIImageSymbolWeightSemibold];
        UIImage* image = [UIImage systemImageNamed:name withConfiguration:configuration];
        if (image == nil)
        {
            image = [UIImage systemImageNamed:name];
        }
        return image;
    }

    NSString* SpeedSymbolName(uint8_t speed)
    {
        if (speed <= 1)
        {
            return @"play.fill";
        }
        if (speed == 2)
        {
            return @"forward.fill";
        }
        if (speed == 3)
        {
            return @"forward.end.fill";
        }
        return @"forward.end.alt.fill";
    }

    void QueueChromeAction(int32_t code, const char* name, int32_t extra)
    {
        const Uint32 eventType = EnsureNativeChromeEventType();
        if (eventType == 0 || eventType == static_cast<Uint32>(-1))
        {
            LOG_ERROR("[OpenRCT2Touch] native chrome: SDL user event registration failed");
            return;
        }

        SDL_Event event{};
        event.type = eventType;
        event.user.code = code;
        event.user.data1 = reinterpret_cast<void*>(static_cast<intptr_t>(extra));
        if (SDL_PushEvent(&event) != 1)
        {
            LOG_ERROR("[OpenRCT2Touch] native chrome: failed to queue %s action", name);
            return;
        }

        NSLog(@"[OpenRCT2Touch] native chrome: queued %s action", name);
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: queued %{public}s action", name);
    }

    NSDictionary* MenuItem(NSString* title, NSString* subtitle, NSString* symbol, NSString* fallback, int32_t action)
    {
        return @{
            @"title" : title,
            @"subtitle" : subtitle,
            @"symbol" : symbol,
            @"fallback" : fallback,
            @"action" : @(action),
        };
    }

    NSArray* BuildMenuItems()
    {
        return @[
            MenuItem(@"Build ride", @"New transport, thrill, gentle, shops", @"plus", @"plus.circle.fill",
                kNativeChromeBuildNewRide),
            MenuItem(@"Trees & scenery", @"Gardens, theming, walls", @"tree.fill", @"leaf.fill", kNativeChromeTrees),
            MenuItem(@"Paths", @"Footpaths, queues, additions",
                @"point.bottomleft.forward.to.point.topright.scurvepath", @"road.lanes", kNativeChromePaths),
            MenuItem(@"Land", @"Raise, lower, and smooth terrain", @"mountain.2.fill", @"triangle.fill",
                kNativeChromeLand),
            MenuItem(@"Water", @"Lakes and rivers", @"drop.fill", @"drop", kNativeChromeWater),
            MenuItem(@"Clear scenery", @"Remove scenery in a brush", @"eraser", @"xmark.circle",
                kNativeChromeClearScenery),
            MenuItem(@"Ride list", @"Inspect and manage existing rides", @"tram.fill", @"bus.fill", kNativeChromeRideList),
        ];
    }

    NSArray* ParkMenuItems()
    {
        return @[
            MenuItem(@"Park info", @"Name, entrance, awards", @"flag.fill", @"flag", kNativeChromeParkInformation),
            MenuItem(@"Staff", @"Handymen, mechanics, security, entertainers", @"person.badge.shield.checkmark.fill",
                @"person.fill", kNativeChromeStaffList),
            MenuItem(@"Guests", @"Thoughts, happiness, and inventory", @"person.3.fill", @"person.2.fill",
                kNativeChromeGuestList),
            MenuItem(@"Finances", @"Cash, loans, and graphs", @"dollarsign.circle.fill", @"creditcard",
                kNativeChromeFinances),
            MenuItem(@"Research", @"Funding and invention order", @"flask.fill", @"chart.bar.fill",
                kNativeChromeResearch),
            MenuItem(@"Messages", @"Park news and objectives", @"newspaper.fill", @"envelope.fill",
                kNativeChromeRecentNews),
        ];
    }

    NSArray* ViewMenuItems()
    {
        return @[
            MenuItem(@"Map", @"Overview of the whole park", @"map.fill", @"map", kNativeChromeMap),
            MenuItem(@"View options", @"See-through rides, underground, heights", @"eye.fill", @"eye",
                kNativeChromeTransparency),
            MenuItem(@"Extra viewport", @"A second camera on the park", @"rectangle.split.2x1.fill",
                @"rectangle.split.2x1", kNativeChromeExtraViewport),
            MenuItem(@"View clipping", @"Cut the world on a plane", @"square.dashed", @"square",
                kNativeChromeViewClipping),
            MenuItem(@"Transparency", @"Fade scenery and supports", @"circle.lefthalf.filled", @"circle",
                kNativeChromeTransparency),
        ];
    }

    NSArray* MoreMenuItems()
    {
        return @[
            MenuItem(@"Save / Load", @"File menu from the disc button", @"square.and.arrow.down",
                @"square.and.arrow.up", kNativeChromeLoadSave),
            MenuItem(@"Options", @"Audio, display, and controls", @"gearshape.fill", @"gear", kNativeChromeOptions),
            MenuItem(@"Cheats", @"Sandbox, clearance, and debug", @"wand.and.stars", @"sparkles", kNativeChromeCheats),
            MenuItem(@"Tile inspector", @"Power-user map cell editor", @"square.grid.3x3.fill", @"square.grid.3x3",
                kNativeChromeTileInspector),
            MenuItem(@"About", @"OpenRCT2 credits and version", @"info.circle.fill", @"info.circle",
                kNativeChromeAbout),
        ];
    }

    NSArray* ViewToggleItems()
    {
        return @[
            MenuItem(@"Underground", @"Look inside from below ground", @"eye.fill", @"eye",
                kNativeChromeViewUnderground),
            MenuItem(@"See-through rides", @"Ghost ride tracks and stations", @"tram.fill", @"tram",
                kNativeChromeViewSeeThroughRides),
            MenuItem(@"See-through scenery", @"Ghost scenery and theming", @"tree.fill", @"leaf.fill",
                kNativeChromeViewSeeThroughScenery),
            MenuItem(@"Guests", @"Show or hide guests", @"person.3.fill", @"person.fill", kNativeChromeViewGuests),
            MenuItem(@"Staff", @"Show or hide staff", @"person.fill", @"person", kNativeChromeViewStaff),
            MenuItem(@"Path issues", @"Highlight broken or blocked paths", @"exclamationmark.triangle.fill",
                @"exclamationmark.triangle", kNativeChromeViewPathIssues),
            MenuItem(@"Height marks", @"Land, track, and path heights", @"ruler.fill", @"ruler",
                kNativeChromeViewHeightMarks),
        ];
    }

    NSArray* OverflowBuildItems()
    {
        NSArray* build = BuildMenuItems();
        if (build.count <= 3)
        {
            return @[];
        }
        return [build subarrayWithRange:NSMakeRange(3, build.count - 3)];
    }

    NSArray* OverflowMenuItems()
    {
        NSMutableArray* items = [NSMutableArray arrayWithArray:OverflowBuildItems()];
        [items addObjectsFromArray:ParkMenuItems()];
        [items addObjectsFromArray:ViewMenuItems()];
        [items addObjectsFromArray:MoreMenuItems()];
        return items;
    }

    NSString* FormatParkCash(money64 cash)
    {
        char amount[OpenRCT2::kMoneyStringMaxlength];
        OpenRCT2::MoneyToString(cash, amount, sizeof(amount), false);
        const auto& currency = OpenRCT2::CurrencyDescriptors[EnumValue(
            OpenRCT2::Config::Get().general.currencyFormat)];
        if (currency.affix_unicode == OpenRCT2::CurrencyAffix::prefix)
        {
            return [NSString stringWithFormat:@"%s%s", currency.symbol_unicode, amount];
        }
        return [NSString stringWithFormat:@"%s%s", amount, currency.symbol_unicode];
    }

    NSString* FormatParkDate(const OpenRCT2::Date& date)
    {
        static NSString* const kMonthNames[] = {
            @"Mar",
            @"Apr",
            @"May",
            @"Jun",
            @"Jul",
            @"Aug",
            @"Sep",
            @"Oct",
        };
        int32_t month = date.GetMonth();
        if (month < 0)
        {
            month = 0;
        }
        else if (month >= MONTH_COUNT)
        {
            month = MONTH_COUNT - 1;
        }
        return [NSString stringWithFormat:@"%@ %d", kMonthNames[month], date.GetDay() + 1];
    }

    // iOS 26 unions adjacent UIGlass buttons in a UIStackView into one capsule.
    // SwiftUI stays separate because GlassEffectContainer spacing matches the
    // HStack. UIKit: wrap each button so glass views are not siblings.
    UIView* IsolateGlassButton(UIButton* button)
    {
        UIView* wrapper = [[UIView alloc] initWithFrame:CGRectZero];
        wrapper.translatesAutoresizingMaskIntoConstraints = NO;
        wrapper.backgroundColor = UIColor.clearColor;
        wrapper.opaque = NO;
        wrapper.userInteractionEnabled = YES;
        [wrapper addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
            [button.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
        ]];
        return wrapper;
    }

    UIView* MakeSeparatedGlassGroup(NSArray* isolatedViews, CGFloat spacing, UILayoutConstraintAxis axis)
    {
        UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:isolatedViews];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = axis;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.spacing = spacing;
        stack.backgroundColor = UIColor.clearColor;
        stack.opaque = NO;

        if (@available(iOS 26.0, *))
        {
            UIGlassContainerEffect* effect = [[UIGlassContainerEffect alloc] init];
            effect.spacing = spacing;
            UIVisualEffectView* container = [[UIVisualEffectView alloc] initWithEffect:effect];
            [effect release];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            container.backgroundColor = UIColor.clearColor;
            [container.contentView addSubview:stack];
            [NSLayoutConstraint activateConstraints:@[
                [stack.leadingAnchor constraintEqualToAnchor:container.contentView.leadingAnchor],
                [stack.trailingAnchor constraintEqualToAnchor:container.contentView.trailingAnchor],
                [stack.topAnchor constraintEqualToAnchor:container.contentView.topAnchor],
                [stack.bottomAnchor constraintEqualToAnchor:container.contentView.bottomAnchor],
            ]];
            [stack release];
            return container;
        }

        return stack;
    }

    BOOL ViewToggleIsOn(int32_t action, uint32_t flags)
    {
        switch (action)
        {
            case kNativeChromeViewUnderground:
                return (flags & OpenRCT2::VIEWPORT_FLAG_UNDERGROUND_INSIDE) != 0;
            case kNativeChromeViewSeeThroughRides:
                return (flags & OpenRCT2::VIEWPORT_FLAG_HIDE_RIDES) != 0;
            case kNativeChromeViewSeeThroughScenery:
                return (flags & OpenRCT2::VIEWPORT_FLAG_HIDE_SCENERY) != 0;
            case kNativeChromeViewGuests:
                return (flags & OpenRCT2::VIEWPORT_FLAG_HIDE_GUESTS) == 0;
            case kNativeChromeViewStaff:
                return (flags & OpenRCT2::VIEWPORT_FLAG_HIDE_STAFF) == 0;
            case kNativeChromeViewPathIssues:
                return (flags & OpenRCT2::VIEWPORT_FLAG_HIGHLIGHT_PATH_ISSUES) != 0;
            case kNativeChromeViewHeightMarks:
                return (flags & kHeightMarkFlags) != 0;
            default:
                return NO;
        }
    }

    const char* ActionLogName(int32_t code)
    {
        switch (code)
        {
            case kNativeChromeBuildNewRide:
                return "build-ride";
            case kNativeChromeTrees:
                return "trees";
            case kNativeChromePaths:
                return "paths";
            case kNativeChromeLand:
                return "land";
            case kNativeChromeWater:
                return "water";
            case kNativeChromeClearScenery:
                return "clear-scenery";
            case kNativeChromeRideList:
                return "ride-list";
            case kNativeChromeParkInformation:
                return "park-information";
            case kNativeChromeStaffList:
                return "staff-list";
            case kNativeChromeGuestList:
                return "guest-list";
            case kNativeChromeFinances:
                return "finances";
            case kNativeChromeResearch:
                return "research";
            case kNativeChromeRecentNews:
                return "recent-news";
            case kNativeChromeMap:
                return "map";
            case kNativeChromeExtraViewport:
                return "extra-viewport";
            case kNativeChromeViewClipping:
                return "view-clipping";
            case kNativeChromeTransparency:
                return "transparency";
            case kNativeChromeLoadSave:
                return "loadsave";
            case kNativeChromeOptions:
                return "options";
            case kNativeChromeAbout:
                return "about";
            case kNativeChromeCheats:
                return "cheats";
            case kNativeChromeTileInspector:
                return "tile-inspector";
            case kNativeChromePause:
                return "pause";
            case kNativeChromeGameSpeed:
                return "game-speed";
            case kNativeChromeZoomIn:
                return "zoom-in";
            case kNativeChromeZoomOut:
                return "zoom-out";
            case kNativeChromeRotateCW:
                return "rotate";
            default:
                return "view-toggle";
        }
    }

    // System sheets receive inset Liquid Glass automatically on iOS 26. Do not wrap
    // the sheet's root view in a second UIGlassEffect (nested glass). Clear list
    // backgrounds so that glass shows through.
    // Docs: https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller
    //       https://developer.apple.com/documentation/uikit/uipresentationcontroller/backgroundeffect
    //       https://developer.apple.com/documentation/uikit/uiglasseffect
    void ConfigureLiquidGlassSheet(UIViewController* controller, BOOL compactUndimmed, BOOL allowDismiss)
    {
        controller.modalPresentationStyle = UIModalPresentationPageSheet;
        controller.modalInPresentation = !allowDismiss;

        UISheetPresentationController* sheet = controller.sheetPresentationController;
        if (sheet == nil)
        {
            return;
        }

        sheet.prefersGrabberVisible = YES;
        // Inset bottom sheet (Find My). Do not let preferredContentSize shrink the
        // sheet into a leading side panel on iPhone.
        sheet.prefersEdgeAttachedInCompactHeight = YES;
        sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
        sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = NO;
        sheet.preferredCornerRadius = 28.0;
        // System sheets already use Liquid Glass. Do not assign backgroundEffect.

        if (@available(iOS 16.0, *))
        {
            UISheetPresentationControllerDetent* medium = [UISheetPresentationControllerDetent mediumDetent];
            UISheetPresentationControllerDetent* large = [UISheetPresentationControllerDetent largeDetent];
            if (compactUndimmed)
            {
                UISheetPresentationControllerDetent* compact = [UISheetPresentationControllerDetent
                    customDetentWithIdentifier:kChromeCompactDetentId
                                      resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                                          (void)context;
                                          return kChromeCompactSheetHeight;
                                      }];
                sheet.detents = @[ compact, medium, large ];
                sheet.selectedDetentIdentifier = kChromeCompactDetentId;
                sheet.largestUndimmedDetentIdentifier = kChromeCompactDetentId;
            }
            else
            {
                sheet.detents = @[ medium, large ];
                sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
            }
        }
        else
        {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent],
            ];
            if (compactUndimmed)
            {
                sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
            }
        }
    }

    void ApplyClearListAppearance(UITableView* tableView)
    {
        tableView.backgroundColor = UIColor.clearColor;
        tableView.opaque = NO;
        tableView.backgroundView = nil;
        tableView.separatorColor = [UIColor.separatorColor colorWithAlphaComponent:0.45];
        tableView.rowHeight = UITableViewAutomaticDimension;
        tableView.estimatedRowHeight = 56.0;
        if (@available(iOS 15.0, *))
        {
            tableView.sectionHeaderTopPadding = 8.0;
        }
    }

    void ApplyClearCellAppearance(UITableViewCell* cell)
    {
        cell.backgroundColor = UIColor.clearColor;
        cell.contentView.backgroundColor = UIColor.clearColor;
        cell.backgroundView = nil;
        cell.multipleSelectionBackgroundView = nil;
        UIView* selected = [[UIView alloc] init];
        selected.backgroundColor = [UIColor.secondarySystemFillColor colorWithAlphaComponent:0.35];
        cell.selectedBackgroundView = selected;
        [selected release];
    }

    bool ChromeControllerIsVisible(UIViewController* presented, UIViewController* content)
    {
        return presented != nil && content != nil
            && (presented == content || presented == content.navigationController);
    }

    void PresentChromeSheet(
        UIViewController* host, UIViewController* content, BOOL compactUndimmed, BOOL allowDismiss,
        id<UIAdaptivePresentationControllerDelegate> delegate)
    {
        UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:content];
        nav.navigationBar.translucent = YES;
        nav.navigationBar.prefersLargeTitles = NO;
        if (@available(iOS 15.0, *))
        {
            UINavigationBarAppearance* appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithTransparentBackground];
            appearance.titleTextAttributes = @{ NSForegroundColorAttributeName : UIColor.labelColor };
            nav.navigationBar.standardAppearance = appearance;
            nav.navigationBar.scrollEdgeAppearance = appearance;
            nav.navigationBar.compactAppearance = appearance;
            [appearance release];
        }
        ConfigureLiquidGlassSheet(nav, compactUndimmed, allowDismiss);
        nav.presentationController.delegate = delegate;
        [host presentViewController:nav animated:YES completion:nil];
        [nav release];
    }
} // namespace

@protocol OpenRCT2TouchChromeHosting <NSObject>
- (void)chromeQueueAction:(int32_t)code extra:(int32_t)extra;
- (void)chromeSelectLayout:(NSInteger)layout;
- (void)chromeDismissOverflow;
- (NSInteger)chromeLayout;
- (uint32_t)chromeViewportFlags;
- (BOOL)chromePaused;
- (uint8_t)chromeSpeed;
@end

@interface OpenRCT2TouchChromeListController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
    NSInteger _mode;
    NSInteger _tab;
    OpenRCT2TouchNativeChrome* _host;
    UITableView* _tableView;
    UIBarButtonItem* _pauseItem;
    UIBarButtonItem* _speedItem;
    UIBarButtonItem* _plusItem;
    UIStackView* _tabStack;
    NSArray* _tabButtons;
}

- (instancetype)initWithMode:(NSInteger)mode host:(OpenRCT2TouchNativeChrome*)host;
- (void)reloadChromeState;

@end

@interface OpenRCT2TouchNativeChrome : NSObject <OpenRCT2TouchChromeHosting, UIAdaptivePresentationControllerDelegate>
{
    UIView* _cluster;
    UIView* _cameraCluster;
    UIView* _statusStrip;
    UIView* _cornerStack;
    UIView* _hostView;
    UIButton* _cameraPauseButton;
    UIButton* _cameraSpeedButton;
    UILabel* _statusCashLabel;
    UILabel* _statusGuestsLabel;
    UILabel* _statusRatingLabel;
    UILabel* _statusDateLabel;
    OpenRCT2TouchChromeListController* _sheetController;
    OpenRCT2TouchChromeListController* _overflowController;
    BOOL _parkOpen;
    NSInteger _layout;
    uint32_t _viewportFlags;
    BOOL _paused;
    uint8_t _speed;
}

- (void)attachToView:(UIView*)parent;
- (void)detach;
- (void)setParkOpen:(BOOL)open;
- (void)updateParkChromeStatePaused:(BOOL)paused speed:(uint8_t)speed flags:(uint32_t)flags;
- (void)updateStatusCash:(NSString*)cash guests:(NSString*)guests rating:(NSString*)rating date:(NSString*)date;

@end

@implementation OpenRCT2TouchChromeListController

- (instancetype)initWithMode:(NSInteger)mode host:(OpenRCT2TouchNativeChrome*)host
{
    self = [super initWithNibName:nil bundle:nil];
    if (self != nil)
    {
        _mode = mode;
        _host = host;
        _tab = kSheetTabBuild;
    }
    return self;
}

- (void)dealloc
{
    [_tableView release];
    _tableView = nil;
    [_pauseItem release];
    _pauseItem = nil;
    [_speedItem release];
    _speedItem = nil;
    [_plusItem release];
    _plusItem = nil;
    [_tabStack release];
    _tabStack = nil;
    [_tabButtons release];
    _tabButtons = nil;
    _host = nil;
    [super dealloc];
}

- (UIButton*)makeTabButtonWithTitle:(NSString*)title symbol:(NSString*)symbol tag:(NSInteger)tag
{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = tag;
    button.accessibilityLabel = title;
    [button addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];

    UIButtonConfiguration* config = [UIButtonConfiguration plainButtonConfiguration];
    config.image = ChromeSymbol(symbol, 14.0);
    config.title = title;
    config.imagePlacement = NSDirectionalRectEdgeTop;
    config.imagePadding = 2.0;
    config.buttonSize = UIButtonConfigurationSizeMini;
    config.baseForegroundColor = UIColor.labelColor;
    button.configuration = config;
    return button;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.clearColor;
    self.view.opaque = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    ApplyClearListAppearance(_tableView);
    [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"menu"];
    [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"toggle"];
    [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"layout"];
    [self.view addSubview:_tableView];

    if (_mode == kChromeListModeOverflow)
    {
        self.title = @"Park tools";
        UIBarButtonItem* close = [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(closeTapped)];
        close.accessibilityLabel = @"Close";
        self.navigationItem.leftBarButtonItem = close;
        [close release];
    }
    else
    {
        _pauseItem = [[UIBarButtonItem alloc] initWithImage:ChromeSymbol(@"pause.fill", 17.0)
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(pauseTapped)];
        _speedItem = [[UIBarButtonItem alloc] initWithImage:ChromeSymbol(@"play.fill", 17.0)
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(speedTapped)];
        _plusItem = [[UIBarButtonItem alloc] initWithImage:ChromeSymbol(@"plus", 17.0)
                                                     style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(plusTapped)];
        _plusItem.accessibilityLabel = @"Build new ride or attraction";
        self.navigationItem.leftBarButtonItems = @[ _pauseItem, _speedItem ];
        [self updateHeaderForTab];
    }

    UIView* tabBar = nil;
    if (_mode == kChromeListModeSheet)
    {
        UIVisualEffect* effect = nil;
        BOOL releaseEffect = NO;
        if (@available(iOS 26.0, *))
        {
            UIGlassEffect* glass = [[UIGlassEffect alloc] init];
            glass.interactive = YES;
            effect = glass;
            releaseEffect = YES;
        }
        else
        {
            effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        }

        UIVisualEffectView* glassBar = [[UIVisualEffectView alloc] initWithEffect:effect];
        if (releaseEffect)
        {
            [effect release];
        }
        glassBar.translatesAutoresizingMaskIntoConstraints = NO;
        glassBar.layer.cornerRadius = 22.0;
        glassBar.clipsToBounds = YES;
        [self.view addSubview:glassBar];
        tabBar = glassBar;

        UIButton* build = [self makeTabButtonWithTitle:@"Build" symbol:@"hammer.fill" tag:kSheetTabBuild];
        UIButton* park = [self makeTabButtonWithTitle:@"Park" symbol:@"flag.fill" tag:kSheetTabPark];
        UIButton* view = [self makeTabButtonWithTitle:@"View" symbol:@"eye.fill" tag:kSheetTabView];
        UIButton* more = [self makeTabButtonWithTitle:@"More" symbol:@"ellipsis" tag:kSheetTabMore];
        _tabButtons = [@[ build, park, view, more ] retain];
        _tabStack = [[UIStackView alloc] initWithArrangedSubviews:_tabButtons];
        _tabStack.translatesAutoresizingMaskIntoConstraints = NO;
        _tabStack.axis = UILayoutConstraintAxisHorizontal;
        _tabStack.distribution = UIStackViewDistributionFillEqually;
        _tabStack.alignment = UIStackViewAlignmentCenter;
        _tabStack.accessibilityLabel = @"Sheet tabs";
        [glassBar.contentView addSubview:_tabStack];
        [NSLayoutConstraint activateConstraints:@[
            [_tabStack.leadingAnchor constraintEqualToAnchor:glassBar.contentView.leadingAnchor constant:8.0],
            [_tabStack.trailingAnchor constraintEqualToAnchor:glassBar.contentView.trailingAnchor constant:-8.0],
            [_tabStack.topAnchor constraintEqualToAnchor:glassBar.contentView.topAnchor constant:4.0],
            [_tabStack.bottomAnchor constraintEqualToAnchor:glassBar.contentView.bottomAnchor constant:-4.0],
        ]];
        [self updateTabAppearance];
        [self updateHeaderForTab];
    }

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    NSMutableArray* constraints = [NSMutableArray arrayWithArray:@[
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    ]];
    if (tabBar != nil)
    {
        [constraints addObjectsFromArray:@[
            [tabBar.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16.0],
            [tabBar.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16.0],
            [tabBar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-6.0],
            [tabBar.heightAnchor constraintEqualToConstant:56.0],
            [_tableView.bottomAnchor constraintEqualToAnchor:tabBar.topAnchor constant:-8.0],
        ]];
    }
    else
    {
        [constraints addObject:[_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    [tabBar release];
    [self reloadChromeState];
}

- (void)updateHeaderForTab
{
    if (_mode != kChromeListModeSheet)
    {
        return;
    }

    NSArray* titles = @[ @"Build", @"Park", @"View", @"More" ];
    if (_tab >= 0 && _tab < static_cast<NSInteger>(titles.count))
    {
        self.title = titles[static_cast<NSUInteger>(_tab)];
    }
    self.navigationItem.rightBarButtonItem = _tab == kSheetTabBuild ? _plusItem : nil;
}

- (void)updateTabAppearance
{
    for (UIButton* button in _tabButtons)
    {
        UIButtonConfiguration* config = button.configuration;
        const BOOL selected = button.tag == _tab;
        config.baseForegroundColor = selected ? UIColor.systemBlueColor : [UIColor.labelColor colorWithAlphaComponent:0.7];
        button.configuration = config;
        if (selected)
        {
            button.accessibilityTraits |= UIAccessibilityTraitSelected;
        }
        else
        {
            button.accessibilityTraits &= ~UIAccessibilityTraitSelected;
        }
    }
}

- (void)reloadChromeState
{
    [self updatePauseAndSpeedButtons];
    [_tableView reloadData];
}

- (void)updatePauseAndSpeedButtons
{
    if (_pauseItem == nil || _speedItem == nil || _host == nil)
    {
        return;
    }

    const BOOL paused = [_host chromePaused];
    _pauseItem.image = ChromeSymbol(paused ? @"play.fill" : @"pause.fill", 17.0);
    _pauseItem.accessibilityLabel = paused ? @"Resume" : @"Pause";
    _speedItem.image = ChromeSymbol(SpeedSymbolName([_host chromeSpeed]), 17.0);
    _speedItem.accessibilityLabel = [NSString stringWithFormat:@"Game speed %d", [_host chromeSpeed]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    (void)tableView;
    if (_mode == kChromeListModeOverflow)
    {
        return 2;
    }
    if (_tab == kSheetTabView)
    {
        return 2;
    }
    if (_tab == kSheetTabMore)
    {
        return 2;
    }
    return 1;
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
    (void)tableView;
    if (_mode == kChromeListModeOverflow)
    {
        return section == 0 ? @"Chrome layout" : nil;
    }
    if (_tab == kSheetTabView)
    {
        return section == 0 ? @"Camera" : @"See-through";
    }
    if (_tab == kSheetTabMore)
    {
        return section == 0 ? @"Chrome layout" : nil;
    }
    return nil;
}

- (NSArray*)itemsForSection:(NSInteger)section
{
    if (_mode == kChromeListModeOverflow)
    {
        return section == 1 ? OverflowMenuItems() : @[];
    }
    switch (_tab)
    {
        case kSheetTabPark:
            return ParkMenuItems();
        case kSheetTabView:
            return section == 0 ? ViewMenuItems() : ViewToggleItems();
        case kSheetTabMore:
            return section == 0 ? @[] : MoreMenuItems();
        default:
            return BuildMenuItems();
    }
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
    (void)tableView;
    if ([self isLayoutSection:section])
    {
        return 1;
    }
    return static_cast<NSInteger>([self itemsForSection:section].count);
}

- (BOOL)isLayoutSection:(NSInteger)section
{
    return (_mode == kChromeListModeOverflow && section == 0)
        || (_mode == kChromeListModeSheet && _tab == kSheetTabMore && section == 0);
}

- (BOOL)isToggleSection:(NSInteger)section
{
    return _mode == kChromeListModeSheet && _tab == kSheetTabView && section == 1;
}

- (void)configureLayoutCell:(UITableViewCell*)cell
{
    ApplyClearCellAppearance(cell);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.contentConfiguration = nil;
    NSArray* existing = [cell.contentView.subviews copy];
    for (UIView* subview in existing)
    {
        [subview removeFromSuperview];
    }
    [existing release];

    UILabel* title = [[UILabel alloc] init];
    title.text = @"Floating cluster or Find My sheet";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    title.textColor = UIColor.secondaryLabelColor;
    title.numberOfLines = 0;

    UISegmentedControl* segments = [[UISegmentedControl alloc] initWithItems:@[ @"Cluster", @"Sheet" ]];
    segments.selectedSegmentIndex = [_host chromeLayout];
    segments.accessibilityLabel = @"Park chrome layout";
    [segments addTarget:self action:@selector(layoutChanged:) forControlEvents:UIControlEventValueChanged];

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title, segments ]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 8.0;
    [cell.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10.0],
        [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10.0],
    ]];
    [stack release];
    [title release];
    [segments release];
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    if ([self isLayoutSection:indexPath.section])
    {
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"layout" forIndexPath:indexPath];
        [self configureLayoutCell:cell];
        return cell;
    }

    NSArray* items = [self itemsForSection:indexPath.section];
    NSDictionary* item = items[static_cast<NSUInteger>(indexPath.row)];
    const int32_t action = [item[@"action"] intValue];
    const BOOL toggleRow = [self isToggleSection:indexPath.section];
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:toggleRow ? @"toggle" : @"menu"
                                                            forIndexPath:indexPath];
    ApplyClearCellAppearance(cell);
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = toggleRow ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;

    UIListContentConfiguration* content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = item[@"title"];
    content.secondaryText = item[@"subtitle"];
    content.textProperties.color = UIColor.labelColor;
    content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
    UIImage* image = ChromeSymbol(item[@"symbol"], 18.0);
    if (image == nil)
    {
        image = ChromeSymbol(item[@"fallback"], 18.0);
    }
    content.image = image;
    content.imageProperties.tintColor = UIColor.labelColor;
    cell.contentConfiguration = content;
    cell.accessibilityLabel = item[@"title"];

    if (toggleRow)
    {
        UISwitch* toggle = [[UISwitch alloc] init];
        toggle.on = ViewToggleIsOn(action, [_host chromeViewportFlags]);
        toggle.tag = action;
        toggle.accessibilityLabel = item[@"title"];
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        [toggle release];
    }

    return cell;
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self isLayoutSection:indexPath.section] || [self isToggleSection:indexPath.section])
    {
        return;
    }

    NSArray* items = [self itemsForSection:indexPath.section];
    NSDictionary* item = items[static_cast<NSUInteger>(indexPath.row)];
    const int32_t action = [item[@"action"] intValue];
    [_host chromeQueueAction:action extra:kChromeExtraXor];
    if (_mode == kChromeListModeOverflow)
    {
        [_host chromeDismissOverflow];
    }
}

- (void)tabTapped:(UIButton*)sender
{
    _tab = sender.tag;
    [self updateTabAppearance];
    [self updateHeaderForTab];
    [_tableView reloadData];
}

- (void)plusTapped
{
    [_host chromeQueueAction:kNativeChromeBuildNewRide extra:kChromeExtraXor];
}

- (void)pauseTapped
{
    [_host chromeQueueAction:kNativeChromePause extra:kChromeExtraXor];
}

- (void)speedTapped
{
    [_host chromeQueueAction:kNativeChromeGameSpeed extra:kChromeExtraXor];
}

- (void)closeTapped
{
    [_host chromeDismissOverflow];
}

- (void)layoutChanged:(UISegmentedControl*)sender
{
    [_host chromeSelectLayout:sender.selectedSegmentIndex];
}

- (void)toggleChanged:(UISwitch*)sender
{
    [_host chromeQueueAction:static_cast<int32_t>(sender.tag) extra:sender.isOn ? 1 : 0];
}

@end

@implementation OpenRCT2TouchNativeChrome

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _layout = [[NSUserDefaults standardUserDefaults] integerForKey:kChromeLayoutDefaultsKey];
        if (_layout != kChromeLayoutSheet)
        {
            _layout = kChromeLayoutCluster;
        }
        _speed = 1;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self detach];
    [super dealloc];
}

- (UIButton*)makeGlassButtonWithSymbol:(NSString*)symbolName
                        fallbackSymbol:(NSString*)fallbackSymbol
                            styleClear:(BOOL)styleClear
                                  size:(CGFloat)size
                            identifier:(NSString*)identifier
                                 label:(NSString*)label
                                action:(SEL)action
{
    UIImage* image = ChromeSymbol(symbolName, size > 50.0 ? 22.0 : 18.0);
    if (image == nil && fallbackSymbol != nil)
    {
        image = ChromeSymbol(fallbackSymbol, size > 50.0 ? 22.0 : 18.0);
    }

    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.accessibilityIdentifier = identifier;
    button.accessibilityLabel = label;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];

    UIButtonConfiguration* config = nil;
    if (@available(iOS 26.0, *))
    {
        if (styleClear)
        {
            config = [UIButtonConfiguration clearGlassButtonConfiguration];
            config.baseForegroundColor = UIColor.labelColor;
        }
        else
        {
            config = [UIButtonConfiguration prominentGlassButtonConfiguration];
            config.baseBackgroundColor = UIColor.systemBlueColor;
            config.baseForegroundColor = UIColor.whiteColor;
        }
    }
    else if (styleClear)
    {
        config = [UIButtonConfiguration grayButtonConfiguration];
        config.baseForegroundColor = UIColor.labelColor;
    }
    else
    {
        config = [UIButtonConfiguration filledButtonConfiguration];
        config.baseBackgroundColor = UIColor.systemBlueColor;
        config.baseForegroundColor = UIColor.whiteColor;
    }

    config.image = image;
    config.title = nil;
    config.subtitle = nil;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    config.buttonSize = size > 50.0 ? UIButtonConfigurationSizeLarge : UIButtonConfigurationSizeMedium;
    config.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);
    button.configuration = config;

    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:size],
        [button.heightAnchor constraintEqualToConstant:size],
    ]];
    return button;
}

- (UIViewController*)hostViewController
{
    UIResponder* responder = _hostView;
    while (responder != nil)
    {
        if ([responder isKindOfClass:UIViewController.class])
        {
            return static_cast<UIViewController*>(responder);
        }
        responder = responder.nextResponder;
    }
    return _hostView.window.rootViewController;
}

- (void)removeTargetsFromView:(UIView*)view
{
    if (view == nil)
    {
        return;
    }
    if ([view isKindOfClass:UIButton.class])
    {
        [static_cast<UIButton*>(view) removeTarget:self action:nil forControlEvents:UIControlEventAllEvents];
    }
    if ([view isKindOfClass:UIStackView.class])
    {
        for (UIView* arranged in static_cast<UIStackView*>(view).arrangedSubviews)
        {
            [self removeTargetsFromView:arranged];
        }
    }
    for (UIView* subview in view.subviews)
    {
        [self removeTargetsFromView:subview];
    }
}

- (void)dismissPresentedChromeAnimated:(BOOL)animated completion:(void (^)())completion
{
    UIViewController* host = [self hostViewController];
    UIViewController* presented = host.presentedViewController;
    OpenRCT2TouchChromeListController* sheet = _sheetController;
    OpenRCT2TouchChromeListController* overflow = _overflowController;
    _sheetController = nil;
    _overflowController = nil;

    auto finish = ^{
        [sheet release];
        [overflow release];
        if (completion != nil)
        {
            completion();
        }
    };

    if (host != nil && presented != nil
        && (ChromeControllerIsVisible(presented, sheet) || ChromeControllerIsVisible(presented, overflow)))
    {
        [host dismissViewControllerAnimated:animated completion:finish];
        return;
    }

    finish();
}

- (void)tearDownOverlay:(UIView**)overlay
{
    if (overlay == nullptr || *overlay == nil)
    {
        return;
    }
    [self removeTargetsFromView:*overlay];
    [*overlay removeFromSuperview];
    [*overlay release];
    *overlay = nil;
}

- (void)tearDownChromeViews
{
    [self dismissPresentedChromeAnimated:NO completion:nil];
    [self tearDownOverlay:&_cluster];
    [self tearDownOverlay:&_cameraCluster];
    [self tearDownOverlay:&_statusStrip];
    [self tearDownOverlay:&_cornerStack];
    _cameraPauseButton = nil;
    _cameraSpeedButton = nil;
    [_statusCashLabel release];
    _statusCashLabel = nil;
    [_statusGuestsLabel release];
    _statusGuestsLabel = nil;
    [_statusRatingLabel release];
    _statusRatingLabel = nil;
    [_statusDateLabel release];
    _statusDateLabel = nil;
}

- (void)applyParkOpenToOverlay:(UIView*)overlay
{
    if (overlay == nil)
    {
        return;
    }
    overlay.hidden = !_parkOpen;
    overlay.userInteractionEnabled = _parkOpen;
}

- (UIStackView*)makeStatusItemWithSymbol:(NSString*)symbol label:(UILabel*)label
{
    UIImageView* icon = [[UIImageView alloc] initWithImage:ChromeSymbol(symbol, 12.0)];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = UIColor.labelColor;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [NSLayoutConstraint activateConstraints:@[
        [icon.widthAnchor constraintEqualToConstant:14.0],
        [icon.heightAnchor constraintEqualToConstant:14.0],
    ]];
    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ icon, label ]];
    [icon release];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 4.0;
    row.alignment = UIStackViewAlignmentCenter;
    return row;
}

- (void)buildStatusStripOnParent:(UIView*)parent above:(UIView*)dock
{
    _statusCashLabel = [[UILabel alloc] init];
    _statusGuestsLabel = [[UILabel alloc] init];
    _statusRatingLabel = [[UILabel alloc] init];
    _statusDateLabel = [[UILabel alloc] init];
    for (UILabel* label in @[ _statusCashLabel, _statusGuestsLabel, _statusRatingLabel, _statusDateLabel ])
    {
        label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        label.textColor = UIColor.labelColor;
        label.text = @"—";
    }

    UIStackView* cash = [self makeStatusItemWithSymbol:@"banknote" label:_statusCashLabel];
    UIStackView* guests = [self makeStatusItemWithSymbol:@"person.3.fill" label:_statusGuestsLabel];
    UIStackView* rating = [self makeStatusItemWithSymbol:@"star.fill" label:_statusRatingLabel];
    UIStackView* date = [self makeStatusItemWithSymbol:@"calendar" label:_statusDateLabel];
    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ cash, guests, rating, date ]];
    [cash release];
    [guests release];
    [rating release];
    [date release];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 16.0;

    UIVisualEffect* effect = nil;
    BOOL releaseEffect = NO;
    if (@available(iOS 26.0, *))
    {
        UIGlassEffect* glass = [[UIGlassEffect alloc] init];
        effect = glass;
        releaseEffect = YES;
    }
    else
    {
        effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }
    UIVisualEffectView* strip = [[UIVisualEffectView alloc] initWithEffect:effect];
    if (releaseEffect)
    {
        [effect release];
    }
    strip.translatesAutoresizingMaskIntoConstraints = NO;
    strip.layer.cornerRadius = 22.0;
    strip.clipsToBounds = YES;
    [strip.contentView addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:strip.contentView.leadingAnchor constant:16.0],
        [row.trailingAnchor constraintEqualToAnchor:strip.contentView.trailingAnchor constant:-16.0],
        [row.topAnchor constraintEqualToAnchor:strip.contentView.topAnchor constant:10.0],
        [row.bottomAnchor constraintEqualToAnchor:strip.contentView.bottomAnchor constant:-10.0],
    ]];
    [row release];

    _statusStrip = strip;
    _statusStrip.accessibilityIdentifier = @"openrct2.touch.statusStrip";
    [self applyParkOpenToOverlay:_statusStrip];
    [parent addSubview:_statusStrip];
    [NSLayoutConstraint activateConstraints:@[
        [_statusStrip.centerXAnchor constraintEqualToAnchor:parent.centerXAnchor],
        [_statusStrip.bottomAnchor constraintEqualToAnchor:dock.topAnchor constant:-kChromeStatusDockGap],
        [_statusStrip.leadingAnchor constraintGreaterThanOrEqualToAnchor:parent.safeAreaLayoutGuide.leadingAnchor
                                                                constant:kChromeHorizontalPadding],
        [_statusStrip.trailingAnchor constraintLessThanOrEqualToAnchor:parent.safeAreaLayoutGuide.trailingAnchor
                                                              constant:-kChromeHorizontalPadding],
    ]];
}

- (void)buildCameraClusterOnParent:(UIView*)parent
{
    UIButton* pause = [self makeGlassButtonWithSymbol:_paused ? @"play.fill" : @"pause.fill"
                                       fallbackSymbol:@"pause.fill"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.pause"
                                                label:_paused ? @"Resume" : @"Pause"
                                               action:@selector(pauseTapped)];
    UIButton* speed = [self makeGlassButtonWithSymbol:SpeedSymbolName(_speed)
                                       fallbackSymbol:@"forward.fill"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.speed"
                                                label:@"Game speed"
                                               action:@selector(speedTapped)];
    UIButton* zoom = [self makeGlassButtonWithSymbol:@"minus.magnifyingglass"
                                      fallbackSymbol:@"minus"
                                          styleClear:YES
                                                size:kChromeSideButtonSize
                                          identifier:@"openrct2.touch.zoomOut"
                                               label:@"Zoom out"
                                              action:@selector(zoomOutTapped)];
    UIButton* rotate = [self makeGlassButtonWithSymbol:@"rotate.right"
                                        fallbackSymbol:@"arrow.clockwise"
                                            styleClear:YES
                                                  size:kChromeSideButtonSize
                                            identifier:@"openrct2.touch.rotate"
                                                 label:@"Rotate view"
                                                action:@selector(rotateTapped)];
    _cameraPauseButton = pause;
    _cameraSpeedButton = speed;

    UIView* pauseWrap = IsolateGlassButton(pause);
    UIView* speedWrap = IsolateGlassButton(speed);
    UIView* zoomWrap = IsolateGlassButton(zoom);
    UIView* rotateWrap = IsolateGlassButton(rotate);
    _cameraCluster = MakeSeparatedGlassGroup(
        @[ pauseWrap, speedWrap, zoomWrap, rotateWrap ], kChromeCameraSpacing, UILayoutConstraintAxisHorizontal);
    [pauseWrap release];
    [speedWrap release];
    [zoomWrap release];
    [rotateWrap release];
    _cameraCluster.accessibilityIdentifier = @"openrct2.touch.cameraCluster";
    [self applyParkOpenToOverlay:_cameraCluster];
    [parent addSubview:_cameraCluster];
    [NSLayoutConstraint activateConstraints:@[
        [_cameraCluster.trailingAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.trailingAnchor
                                                      constant:-kChromeHorizontalPadding],
        [_cameraCluster.topAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.topAnchor],
    ]];
}

- (void)buildClusterOnParent:(UIView*)parent
{
    UIButton* trees = [self makeGlassButtonWithSymbol:@"tree.fill"
                                       fallbackSymbol:@"leaf.fill"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.trees"
                                                label:@"Trees"
                                               action:@selector(treesTapped)];
    UIButton* ride = [self makeGlassButtonWithSymbol:@"plus"
                                      fallbackSymbol:@"plus.circle.fill"
                                          styleClear:NO
                                                size:kChromeRideButtonSize
                                          identifier:@"openrct2.touch.buildRide"
                                               label:@"Build new ride or attraction"
                                              action:@selector(buildRideTapped)];
    UIButton* paths = [self makeGlassButtonWithSymbol:@"point.bottomleft.forward.to.point.topright.scurvepath"
                                       fallbackSymbol:@"road.lanes"
                                           styleClear:YES
                                                 size:kChromeSideButtonSize
                                           identifier:@"openrct2.touch.paths"
                                                label:@"Paths"
                                               action:@selector(pathsTapped)];
    UIButton* more = [self makeGlassButtonWithSymbol:@"ellipsis"
                                      fallbackSymbol:@"ellipsis.circle"
                                          styleClear:YES
                                                size:kChromeSideButtonSize
                                          identifier:@"openrct2.touch.more"
                                               label:@"More tools"
                                              action:@selector(moreTapped)];

    UIView* treesWrap = IsolateGlassButton(trees);
    UIView* rideWrap = IsolateGlassButton(ride);
    UIView* pathsWrap = IsolateGlassButton(paths);
    UIView* moreWrap = IsolateGlassButton(more);
    _cluster = MakeSeparatedGlassGroup(
        @[ treesWrap, rideWrap, pathsWrap, moreWrap ], kChromeButtonSpacing, UILayoutConstraintAxisHorizontal);
    [treesWrap release];
    [rideWrap release];
    [pathsWrap release];
    [moreWrap release];
    _cluster.accessibilityIdentifier = @"openrct2.touch.nativeChrome";
    [self applyParkOpenToOverlay:_cluster];
    [parent addSubview:_cluster];
    [NSLayoutConstraint activateConstraints:@[
        [_cluster.centerXAnchor constraintEqualToAnchor:parent.centerXAnchor],
        [_cluster.bottomAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.bottomAnchor
                                              constant:-kChromeDockBottomPadding],
        [_cluster.leadingAnchor constraintGreaterThanOrEqualToAnchor:parent.safeAreaLayoutGuide.leadingAnchor
                                                            constant:kChromeHorizontalPadding],
        [_cluster.trailingAnchor constraintLessThanOrEqualToAnchor:parent.safeAreaLayoutGuide.trailingAnchor
                                                          constant:-kChromeHorizontalPadding],
    ]];

    [self buildStatusStripOnParent:parent above:_cluster];
    [self buildCameraClusterOnParent:parent];
}

- (void)buildCornerControlsOnParent:(UIView*)parent
{
    UIButton* layers = [self makeGlassButtonWithSymbol:@"square.3.layers.3d.top.filled"
                                        fallbackSymbol:@"eye.fill"
                                            styleClear:YES
                                                  size:kChromeSideButtonSize
                                            identifier:@"openrct2.touch.viewOptions"
                                                 label:@"View options"
                                                action:@selector(viewOptionsTapped)];
    UIButton* map = [self makeGlassButtonWithSymbol:@"location.fill"
                                     fallbackSymbol:@"map.fill"
                                         styleClear:YES
                                               size:kChromeSideButtonSize
                                         identifier:@"openrct2.touch.map"
                                              label:@"Center park"
                                             action:@selector(mapTapped)];
    UIView* layersWrap = IsolateGlassButton(layers);
    UIView* mapWrap = IsolateGlassButton(map);
    _cornerStack = MakeSeparatedGlassGroup(
        @[ layersWrap, mapWrap ], kChromeCameraSpacing, UILayoutConstraintAxisVertical);
    [layersWrap release];
    [mapWrap release];
    [self applyParkOpenToOverlay:_cornerStack];
    [parent addSubview:_cornerStack];
    [NSLayoutConstraint activateConstraints:@[
        [_cornerStack.trailingAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.trailingAnchor
                                                    constant:-kChromeHorizontalPadding],
        [_cornerStack.topAnchor constraintEqualToAnchor:parent.safeAreaLayoutGuide.topAnchor constant:12.0],
    ]];
}

- (void)buildChrome
{
    if (_hostView == nil)
    {
        return;
    }

    if (_layout == kChromeLayoutSheet)
    {
        [self buildCornerControlsOnParent:_hostView];
    }
    else
    {
        [self buildClusterOnParent:_hostView];
    }
}

- (void)presentSheetIfNeeded
{
    if (!_parkOpen || _layout != kChromeLayoutSheet)
    {
        return;
    }

    UIViewController* host = [self hostViewController];
    if (host == nil)
    {
        return;
    }

    if (ChromeControllerIsVisible(host.presentedViewController, _sheetController))
    {
        return;
    }

    if (host.presentedViewController != nil)
    {
        [host dismissViewControllerAnimated:NO completion:^{
            [self presentSheetIfNeeded];
        }];
        return;
    }

    [_sheetController release];
    OpenRCT2TouchChromeListController* sheet = [[OpenRCT2TouchChromeListController alloc] initWithMode:kChromeListModeSheet
                                                                                                  host:self];
    PresentChromeSheet(host, sheet, YES, NO, self);
    _sheetController = sheet;
}

- (void)rebuildChrome
{
    if (_hostView == nil)
    {
        return;
    }
    [self tearDownChromeViews];
    [self buildChrome];
    [self setParkOpen:_parkOpen];
}

- (void)bringChromeToFront
{
    if (_hostView == nil)
    {
        return;
    }
    if (_cameraCluster != nil)
    {
        [_hostView bringSubviewToFront:_cameraCluster];
    }
    if (_statusStrip != nil)
    {
        [_hostView bringSubviewToFront:_statusStrip];
    }
    if (_cluster != nil)
    {
        [_hostView bringSubviewToFront:_cluster];
    }
    if (_cornerStack != nil)
    {
        [_hostView bringSubviewToFront:_cornerStack];
    }
}

- (void)attachToView:(UIView*)parent
{
    if (parent == nil)
    {
        return;
    }

    const BOOL alreadyAttached = _hostView == parent
        && (_cluster.superview == parent || _cameraCluster.superview == parent || _cornerStack.superview == parent);
    if (alreadyAttached)
    {
        [self bringChromeToFront];
        return;
    }

    [self detach];
    _hostView = parent;
    [self buildChrome];
    [self bringChromeToFront];

    NSLog(@"[OpenRCT2Touch] native chrome: attached park overlay");
    os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: attached park overlay");
}

- (void)detach
{
    [self tearDownChromeViews];
    _hostView = nil;
    _parkOpen = NO;
}

- (void)setParkOpen:(BOOL)open
{
    _parkOpen = open;
    [self applyParkOpenToOverlay:_cluster];
    [self applyParkOpenToOverlay:_cameraCluster];
    [self applyParkOpenToOverlay:_statusStrip];
    [self applyParkOpenToOverlay:_cornerStack];

    if (open)
    {
        [self bringChromeToFront];
        if (_layout == kChromeLayoutSheet)
        {
            [self presentSheetIfNeeded];
        }
    }
    else
    {
        [self dismissPresentedChromeAnimated:YES completion:nil];
    }
}

- (void)updateCameraPauseAndSpeed
{
    if (_cameraPauseButton != nil)
    {
        UIButtonConfiguration* pauseConfig = _cameraPauseButton.configuration;
        pauseConfig.image = ChromeSymbol(_paused ? @"play.fill" : @"pause.fill", 18.0);
        _cameraPauseButton.configuration = pauseConfig;
        _cameraPauseButton.accessibilityLabel = _paused ? @"Resume" : @"Pause";
    }
    if (_cameraSpeedButton != nil)
    {
        UIButtonConfiguration* speedConfig = _cameraSpeedButton.configuration;
        speedConfig.image = ChromeSymbol(SpeedSymbolName(_speed), 18.0);
        _cameraSpeedButton.configuration = speedConfig;
        _cameraSpeedButton.accessibilityLabel = [NSString stringWithFormat:@"Game speed %d", _speed];
    }
}

- (void)updateParkChromeStatePaused:(BOOL)paused speed:(uint8_t)speed flags:(uint32_t)flags
{
    if (_paused == paused && _speed == speed && _viewportFlags == flags)
    {
        return;
    }
    _paused = paused;
    _speed = speed;
    _viewportFlags = flags;
    [self updateCameraPauseAndSpeed];
    [_sheetController reloadChromeState];
    [_overflowController reloadChromeState];
}

- (void)updateStatusCash:(NSString*)cash guests:(NSString*)guests rating:(NSString*)rating date:(NSString*)date
{
    _statusCashLabel.text = cash;
    _statusGuestsLabel.text = guests;
    _statusRatingLabel.text = rating;
    _statusDateLabel.text = date;
    _statusStrip.accessibilityLabel = [NSString
        stringWithFormat:@"Cash %@, %@ guests, park rating %@, %@", cash, guests, rating, date];
}

- (void)treesTapped
{
    QueueChromeAction(kNativeChromeTrees, "trees", kChromeExtraXor);
}

- (void)buildRideTapped
{
    QueueChromeAction(kNativeChromeBuildNewRide, "build-ride", kChromeExtraXor);
}

- (void)pathsTapped
{
    QueueChromeAction(kNativeChromePaths, "paths", kChromeExtraXor);
}

- (void)moreTapped
{
    if (_overflowController != nil || _layout != kChromeLayoutCluster)
    {
        return;
    }

    UIViewController* host = [self hostViewController];
    if (host == nil || host.presentedViewController != nil)
    {
        return;
    }

    OpenRCT2TouchChromeListController* overflow = [[OpenRCT2TouchChromeListController alloc]
        initWithMode:kChromeListModeOverflow
                host:self];
    PresentChromeSheet(host, overflow, NO, YES, self);
    _overflowController = overflow;
}

- (void)pauseTapped
{
    QueueChromeAction(kNativeChromePause, "pause", kChromeExtraXor);
}

- (void)speedTapped
{
    QueueChromeAction(kNativeChromeGameSpeed, "game-speed", kChromeExtraXor);
}

- (void)zoomOutTapped
{
    QueueChromeAction(kNativeChromeZoomOut, "zoom-out", kChromeExtraXor);
}

- (void)mapTapped
{
    QueueChromeAction(kNativeChromeMap, "map", kChromeExtraXor);
}

- (void)viewOptionsTapped
{
    QueueChromeAction(kNativeChromeTransparency, "transparency", kChromeExtraXor);
}

- (void)rotateTapped
{
    QueueChromeAction(kNativeChromeRotateCW, "rotate", kChromeExtraXor);
}

- (void)chromeQueueAction:(int32_t)code extra:(int32_t)extra
{
    QueueChromeAction(code, ActionLogName(code), extra);
}

- (void)chromeSelectLayout:(NSInteger)layout
{
    const NSInteger nextLayout = layout == kChromeLayoutSheet ? kChromeLayoutSheet : kChromeLayoutCluster;
    if (nextLayout == _layout)
    {
        return;
    }

    _layout = nextLayout;
    [[NSUserDefaults standardUserDefaults] setInteger:_layout forKey:kChromeLayoutDefaultsKey];
    [self dismissPresentedChromeAnimated:YES completion:^{
        [self rebuildChrome];
    }];
}

- (void)chromeDismissOverflow
{
    UIViewController* host = [self hostViewController];
    OpenRCT2TouchChromeListController* overflow = _overflowController;
    _overflowController = nil;
    if (host != nil && ChromeControllerIsVisible(host.presentedViewController, overflow))
    {
        [host dismissViewControllerAnimated:YES completion:^{
            [overflow release];
        }];
        return;
    }
    [overflow release];
}

- (NSInteger)chromeLayout
{
    return _layout;
}

- (uint32_t)chromeViewportFlags
{
    return _viewportFlags;
}

- (BOOL)chromePaused
{
    return _paused;
}

- (uint8_t)chromeSpeed
{
    return _speed;
}

- (void)presentationControllerDidDismiss:(UIPresentationController*)presentationController
{
    UIViewController* dismissed = presentationController.presentedViewController;
    if (ChromeControllerIsVisible(dismissed, _overflowController))
    {
        [_overflowController release];
        _overflowController = nil;
    }
    else if (ChromeControllerIsVisible(dismissed, _sheetController))
    {
        [_sheetController release];
        _sheetController = nil;
        if (_parkOpen && _layout == kChromeLayoutSheet)
        {
            [self presentSheetIfNeeded];
        }
    }
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    (void)notification;
    if ((_cluster == nil || _cluster.superview == nil) && (_cameraCluster == nil || _cameraCluster.superview == nil)
        && (_cornerStack == nil || _cornerStack.superview == nil))
    {
        OpenRCT2::Ui::NativeChromeAttach(nullptr);
    }
    else
    {
        [self bringChromeToFront];
    }
}

@end

namespace OpenRCT2::Ui
{
    namespace
    {
        OpenRCT2TouchNativeChrome* gNativeChrome = nil;
        int gChromeLastParkOpen = -1;
        int gChromeLastPaused = -1;
        int gChromeLastSpeed = -1;
        uint32_t gChromeLastFlags = 0xFFFFFFFFu;
        money64 gChromeLastCash = kMoney64Undefined;
        uint32_t gChromeLastGuests = 0xFFFFFFFFu;
        uint16_t gChromeLastRating = 0xFFFFu;
        int32_t gChromeLastMonth = -1;
        int32_t gChromeLastDay = -1;

        UIWindow* WindowFromSdl(SDL_Window* window)
        {
            if (window != nullptr)
            {
                SDL_SysWMinfo windowInfo = {};
                SDL_VERSION(&windowInfo.version);
                if (SDL_GetWindowWMInfo(window, &windowInfo) == SDL_TRUE && windowInfo.subsystem == SDL_SYSWM_UIKIT)
                {
                    UIWindow* uikitWindow = windowInfo.info.uikit.window;
                    if (uikitWindow != nil && uikitWindow.rootViewController != nil)
                    {
                        return uikitWindow;
                    }
                }
            }

            UIWindow* fallback = nil;
            for (UIScene* scene in UIApplication.sharedApplication.connectedScenes)
            {
                if (![scene isKindOfClass:UIWindowScene.class])
                {
                    continue;
                }

                for (UIWindow* candidate in static_cast<UIWindowScene*>(scene).windows)
                {
                    if (candidate.hidden || candidate.rootViewController == nil)
                    {
                        continue;
                    }

                    fallback = candidate;
                    if (candidate.isKeyWindow)
                    {
                        return candidate;
                    }
                }
            }
            return fallback;
        }

        void AttachOnMainThread(SDL_Window* window)
        {
            if (gNativeChrome == nil)
            {
                gNativeChrome = [OpenRCT2TouchNativeChrome new];
            }

            UIWindow* host = WindowFromSdl(window);
            UIView* parent = host.rootViewController.view;
            if (host == nil || parent == nil)
            {
                NSLog(@"[OpenRCT2Touch] native chrome: no UIKit window yet");
                os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: no UIKit window yet");
                return;
            }

            [gNativeChrome attachToView:parent];
            gChromeLastParkOpen = -1;
        }

        bool ParkIsOpen()
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
                || windowMgr->FindByClass(WindowClass::scenarioSelect) != nullptr)
            {
                return false;
            }

            return true;
        }

        void ApplyViewportFlag(uint32_t flag, int32_t extra, bool switchOnClearsFlag)
        {
            auto* w = WindowGetMain();
            if (w == nullptr || w->viewport == nullptr)
            {
                return;
            }

            if (extra < 0)
            {
                w->viewport->flags ^= flag;
            }
            else if (switchOnClearsFlag)
            {
                if (extra != 0)
                {
                    w->viewport->flags &= ~flag;
                }
                else
                {
                    w->viewport->flags |= flag;
                }
            }
            else if (extra != 0)
            {
                w->viewport->flags |= flag;
            }
            else
            {
                w->viewport->flags &= ~flag;
            }
            w->invalidate();
        }

        void ApplyHeightMarks(int32_t extra)
        {
            auto* w = WindowGetMain();
            if (w == nullptr || w->viewport == nullptr)
            {
                return;
            }

            if (extra < 0)
            {
                if ((w->viewport->flags & kHeightMarkFlags) != 0)
                {
                    w->viewport->flags &= ~kHeightMarkFlags;
                }
                else
                {
                    w->viewport->flags |= kHeightMarkFlags;
                }
            }
            else if (extra != 0)
            {
                w->viewport->flags |= kHeightMarkFlags;
            }
            else
            {
                w->viewport->flags &= ~kHeightMarkFlags;
            }
            w->invalidate();
        }

        void CycleGameSpeed()
        {
            uint8_t newSpeed = gGameSpeed + 1;
            if (newSpeed < 1 || newSpeed > 4)
            {
                newSpeed = 1;
            }
            auto setSpeedAction = GameActions::GameSetSpeedAction(newSpeed);
            GameActions::Execute(&setSpeedAction, getGameState());
        }
    } // namespace

    void NativeChromeAttach(SDL_Window* window)
    {
        static SDL_Window* sWindow = nullptr;
        if (window != nullptr)
        {
            sWindow = window;
        }

        EnsureNativeChromeEventType();

        SDL_Window* target = window != nullptr ? window : sWindow;
        auto attach = ^{
            AttachOnMainThread(target);
        };

        if ([NSThread isMainThread])
        {
            attach();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), attach);
        }
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), attach);
    }

    void NativeChromeDetach()
    {
        auto detach = ^{
            [gNativeChrome detach];
            [gNativeChrome release];
            gNativeChrome = nil;
            gChromeLastParkOpen = -1;
            gChromeLastPaused = -1;
            gChromeLastSpeed = -1;
            gChromeLastFlags = 0xFFFFFFFFu;
            gChromeLastCash = kMoney64Undefined;
            gChromeLastGuests = 0xFFFFFFFFu;
            gChromeLastRating = 0xFFFFu;
            gChromeLastMonth = -1;
            gChromeLastDay = -1;
        };

        if ([NSThread isMainThread])
        {
            detach();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), detach);
        }
    }

    void NativeChromeTick()
    {
        if (gNativeChrome == nil)
        {
            return;
        }

        const int open = ParkIsOpen() ? 1 : 0;
        int paused = 0;
        int speed = 1;
        uint32_t flags = 0;
        money64 cashValue = kMoney64Undefined;
        uint32_t guestsValue = 0;
        uint16_t ratingValue = 0;
        int32_t monthValue = -1;
        int32_t dayValue = -1;
        NSString* cashText = nil;
        NSString* guestsText = nil;
        NSString* ratingText = nil;
        NSString* dateText = nil;
        if (open != 0)
        {
            paused = GameIsPaused() ? 1 : 0;
            speed = gGameSpeed;
            auto* mainWindow = WindowGetMain();
            if (mainWindow != nullptr && mainWindow->viewport != nullptr)
            {
                flags = mainWindow->viewport->flags;
            }

            const auto& gameState = getGameState();
            cashValue = gameState.park.cash;
            guestsValue = gameState.park.numGuestsInPark;
            ratingValue = gameState.park.rating;
            monthValue = gameState.date.GetMonth();
            dayValue = gameState.date.GetDay();
            cashText = [FormatParkCash(cashValue) retain];
            guestsText = [[NSString alloc] initWithFormat:@"%u", guestsValue];
            ratingText = [[NSString alloc] initWithFormat:@"%u", ratingValue];
            dateText = [FormatParkDate(gameState.date) retain];
        }

        const BOOL parkOpenChanged = open != gChromeLastParkOpen;
        const BOOL chromeStateChanged = paused != gChromeLastPaused || speed != gChromeLastSpeed || flags != gChromeLastFlags;
        const BOOL statusChanged = cashValue != gChromeLastCash || guestsValue != gChromeLastGuests
            || ratingValue != gChromeLastRating || monthValue != gChromeLastMonth || dayValue != gChromeLastDay;
        if (!parkOpenChanged && !chromeStateChanged && !statusChanged)
        {
            [cashText release];
            [guestsText release];
            [ratingText release];
            [dateText release];
            return;
        }

        gChromeLastParkOpen = open;
        gChromeLastPaused = paused;
        gChromeLastSpeed = speed;
        gChromeLastFlags = flags;
        gChromeLastCash = cashValue;
        gChromeLastGuests = guestsValue;
        gChromeLastRating = ratingValue;
        gChromeLastMonth = monthValue;
        gChromeLastDay = dayValue;

        auto sync = ^{
            if (parkOpenChanged)
            {
                [gNativeChrome setParkOpen:open != 0];
            }
            if (parkOpenChanged || chromeStateChanged)
            {
                [gNativeChrome updateParkChromeStatePaused:paused != 0 speed:static_cast<uint8_t>(speed) flags:flags];
            }
            if (open != 0 && (parkOpenChanged || statusChanged))
            {
                [gNativeChrome updateStatusCash:cashText guests:guestsText rating:ratingText date:dateText];
            }
            [cashText release];
            [guestsText release];
            [ratingText release];
            [dateText release];
        };
        if ([NSThread isMainThread])
        {
            sync();
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), sync);
        }
    }

    bool NativeChromeHandleEvent(const SDL_Event& event)
    {
        if (gNativeChromeEventType == 0 || gNativeChromeEventType == static_cast<Uint32>(-1)
            || event.type != gNativeChromeEventType)
        {
            return false;
        }

        if (!ParkIsOpen())
        {
            return true;
        }

        const int32_t extra = static_cast<int32_t>(reinterpret_cast<intptr_t>(event.user.data1));
        WindowBase* mainWindow = nullptr;

        switch (event.user.code)
        {
            case kNativeChromeBuildNewRide:
                OpenRCT2::ContextOpenWindow(WindowClass::constructRide);
                break;
            case kNativeChromeTrees:
                Windows::ToggleSceneryWindow();
                break;
            case kNativeChromePaths:
                Windows::ToggleFootpathWindow();
                break;
            case kNativeChromeLand:
                Windows::ToggleLandWindow();
                break;
            case kNativeChromeWater:
                Windows::ToggleWaterWindow();
                break;
            case kNativeChromeClearScenery:
                Windows::ToggleClearSceneryWindow();
                break;
            case kNativeChromeRideList:
                OpenRCT2::ContextOpenWindow(WindowClass::rideList);
                break;
            case kNativeChromeParkInformation:
                OpenRCT2::ContextOpenWindow(WindowClass::parkInformation);
                break;
            case kNativeChromeStaffList:
                OpenRCT2::ContextOpenWindow(WindowClass::staffList);
                break;
            case kNativeChromeGuestList:
                OpenRCT2::ContextOpenWindow(WindowClass::guestList);
                break;
            case kNativeChromeFinances:
                OpenRCT2::ContextOpenWindow(WindowClass::finances);
                break;
            case kNativeChromeResearch:
                OpenRCT2::ContextOpenWindow(WindowClass::research);
                break;
            case kNativeChromeRecentNews:
                OpenRCT2::ContextOpenWindow(WindowClass::recentNews);
                break;
            case kNativeChromeMap:
                OpenRCT2::ContextOpenWindow(WindowClass::map);
                break;
            case kNativeChromeExtraViewport:
                OpenRCT2::ContextOpenWindow(WindowClass::viewport);
                break;
            case kNativeChromeViewClipping:
                OpenRCT2::ContextOpenWindow(WindowClass::viewClipping);
                break;
            case kNativeChromeTransparency:
                OpenRCT2::ContextOpenWindow(WindowClass::transparency);
                break;
            case kNativeChromeLoadSave:
                SaveGameAs();
                break;
            case kNativeChromeOptions:
                OpenRCT2::ContextOpenWindow(WindowClass::options);
                break;
            case kNativeChromeAbout:
                OpenRCT2::ContextOpenWindow(WindowClass::about);
                break;
            case kNativeChromeCheats:
                OpenRCT2::ContextOpenWindow(WindowClass::cheats);
                break;
            case kNativeChromeTileInspector:
                OpenRCT2::ContextOpenWindow(WindowClass::tileInspector);
                break;
            case kNativeChromePause:
                if (Network::GetMode() != Network::Mode::client)
                {
                    auto pauseToggleAction = GameActions::PauseToggleAction();
                    GameActions::Execute(&pauseToggleAction, getGameState());
                }
                break;
            case kNativeChromeGameSpeed:
                CycleGameSpeed();
                break;
            case kNativeChromeZoomIn:
                mainWindow = WindowGetMain();
                if (mainWindow != nullptr)
                {
                    Windows::WindowZoomIn(*mainWindow, false);
                }
                break;
            case kNativeChromeZoomOut:
                mainWindow = WindowGetMain();
                if (mainWindow != nullptr)
                {
                    Windows::WindowZoomOut(*mainWindow, false);
                }
                break;
            case kNativeChromeRotateCW:
                ViewportRotateAll(1);
                break;
            case kNativeChromeViewUnderground:
                ApplyViewportFlag(VIEWPORT_FLAG_UNDERGROUND_INSIDE, extra, false);
                break;
            case kNativeChromeViewSeeThroughRides:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_RIDES, extra, false);
                break;
            case kNativeChromeViewSeeThroughScenery:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_SCENERY, extra, false);
                break;
            case kNativeChromeViewGuests:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_GUESTS, extra, true);
                break;
            case kNativeChromeViewStaff:
                ApplyViewportFlag(VIEWPORT_FLAG_HIDE_STAFF, extra, true);
                break;
            case kNativeChromeViewPathIssues:
                ApplyViewportFlag(VIEWPORT_FLAG_HIGHLIGHT_PATH_ISSUES, extra, false);
                break;
            case kNativeChromeViewHeightMarks:
                ApplyHeightMarks(extra);
                break;
            default:
                break;
        }
        os_log_info(OS_LOG_DEFAULT, "[OpenRCT2Touch] native chrome: invoked action %d", event.user.code);
        return true;
    }
} // namespace OpenRCT2::Ui

#endif // TARGET_OS_IOS
