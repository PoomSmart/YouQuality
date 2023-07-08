#import <rootless.h>
#import "../YouTubeHeader/YTColor.h"
#import "../YouTubeHeader/YTCommonUtils.h"
#import "../YouTubeHeader/YTInlinePlayerBarContainerView.h"
#import "../YouTubeHeader/YTMainAppControlsOverlayView.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h"
#import "../YouTubeHeader/YTSingleVideoController.h"
#import "../YouTubeHeader/YTSettingsPickerViewController.h"
#import "../YouTubeHeader/YTSettingsViewController.h"
#import "../YouTubeHeader/YTSettingsSectionItem.h"
#import "../YouTubeHeader/YTSettingsSectionItemManager.h"
#import "../YouTubeHeader/YTQTMButton.h"
#import "../YouTubeHeader/QTMIcon.h"
#import "../YouTubeHeader/MLFormat.h"
#import "../YouTubeHeader/UIView+YouTube.h"
#import <HBLog.h>

#define EnabledKey @"YTVideoOverlay-YouQuality-Enabled"
#define PositionKey @"YTVideoOverlay-YouQuality-Position"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]

static const NSInteger YouQualitySection = 599;

@interface YTSettingsSectionItemManager (YouQuality)
- (void)updateYouQualitySectionWithEntry:(id)entry;
@end

@interface YTMainAppControlsOverlayView (YouQuality)
@property (retain, nonatomic) YTQTMButton *qualityButton;
- (void)didPressYouQuality:(id)arg;
- (void)updateYouQualityButton:(id)arg;
@end

@interface YTInlinePlayerBarContainerView (YouQuality)
@property (retain, nonatomic) YTQTMButton *qualityButton;
- (void)didPressYouQuality:(id)arg;
- (void)updateYouQualityButton:(id)arg;
@end

static BOOL TweakEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:EnabledKey];
}

static int QualityButtonPosition() {
    return [[NSUserDefaults standardUserDefaults] integerForKey:PositionKey];
}

NSString *YouQualityUpdateNotification = @"YouQualityUpdateNotification";
NSString *currentQualityLabel = @"na";

static BOOL UseTopQualityButton() {
    return TweakEnabled() && QualityButtonPosition() == 0;
}

static BOOL UseBottomQualityButton() {
    return TweakEnabled() && QualityButtonPosition() == 1;
}

static NSMutableArray *topControls(YTMainAppControlsOverlayView *self, NSMutableArray *controls) {
    if (UseTopQualityButton())
        [controls insertObject:self.qualityButton atIndex:0];
    return controls;
}

NSBundle *YouQualityBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouQuality" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/YouQuality.bundle")];
    });
    return bundle;
}

static UIImage *qualityImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:qualityLabel inBundle:YouQualityBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

static void createQualityButtonTop(YTMainAppControlsOverlayView *self) {
    if (!self) return;
    CGFloat padding = [[self class] topButtonAdditionalPadding];
    UIImage *image = qualityImage(currentQualityLabel);
    self.qualityButton = [self buttonWithImage:image accessibilityLabel:@"Quality" verticalContentPadding:padding];
    self.qualityButton.hidden = YES;
    self.qualityButton.alpha = 0;
    [self.qualityButton addTarget:self action:@selector(didPressYouQuality:) forControlEvents:UIControlEventTouchUpInside];
    @try {
        [[self valueForKey:@"_topControlsAccessibilityContainerView"] addSubview:self.qualityButton];
    } @catch (id ex) {
        [self addSubview:self.qualityButton];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouQualityButton:) name:YouQualityUpdateNotification object:nil];
}

static void createQualityButtonBottom(YTInlinePlayerBarContainerView *self) {
    if (!self) return;
    UIImage *image = qualityImage(currentQualityLabel);
    self.qualityButton = [%c(YTQTMButton) iconButton];
    self.qualityButton.hidden = YES;
    self.qualityButton.exclusiveTouch = YES;
    self.qualityButton.alpha = 0;
    self.qualityButton.minHitTargetSize = 60;
    self.qualityButton.accessibilityLabel = @"Quality";
    [self.qualityButton setImage:image forState:0];
    [self.qualityButton sizeToFit];
    [self.qualityButton addTarget:self action:@selector(didPressYouQuality:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.qualityButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouQualityButton:) name:YouQualityUpdateNotification object:nil];
}

%group Video

%hook YTSingleVideoController

- (void)playerItem:(id)playerItem didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = [format qualityLabel];
    [[NSNotificationCenter defaultCenter] postNotificationName:YouQualityUpdateNotification object:nil];
    %orig;
}

%end

%end

%group Top

%hook YTMainAppVideoPlayerOverlayViewController

- (void)updateTopRightButtonAvailability {
    %orig;
    YTMainAppVideoPlayerOverlayView *v = [self videoPlayerOverlayView];
    YTMainAppControlsOverlayView *c = [v valueForKey:@"_controlsOverlayView"];
    c.qualityButton.hidden = !UseTopQualityButton();
    [c setNeedsLayout];
}

%end

%hook YTMainAppControlsOverlayView

%property (retain, nonatomic) YTQTMButton *qualityButton;

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    createQualityButtonTop(self);
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    createQualityButtonTop(self);
    return self;
}

- (NSMutableArray *)topButtonControls {
    return topControls(self, %orig);
}

- (NSMutableArray *)topControls {
    return topControls(self, %orig);
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)canceledState {
    if (UseTopQualityButton())
        self.qualityButton.alpha = canceledState || !visible ? 0.0 : 1.0;
    %orig;
}

%new(v@:@)
- (void)updateYouQualityButton:(id)arg {
    [self.qualityButton setImage:qualityImage(currentQualityLabel) forState:0];
}

%new(v@:@)
- (void)didPressYouQuality:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self valueForKey:@"_eventsDelegate"];
    [c didPressVideoQuality:arg];
    [self updateYouQualityButton:nil];
}

%end

%end

%group Bottom

%hook YTInlinePlayerBarContainerView

%property (retain, nonatomic) YTQTMButton *qualityButton;

- (id)init {
    self = %orig;
    createQualityButtonBottom(self);
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (NSMutableArray *)rightIcons {
    NSMutableArray *icons = %orig;
    if (UseBottomQualityButton() && ![icons containsObject:self.qualityButton])
        [icons insertObject:self.qualityButton atIndex:0];
    return icons;
}

- (void)updateIconVisibility {
    %orig;
    if (UseBottomQualityButton())
        self.qualityButton.hidden = NO;
}

- (void)hideScrubber {
    %orig;
    if (UseBottomQualityButton())
        self.qualityButton.alpha = 0;
}

- (void)setPeekableViewVisible:(BOOL)visible fullscreenButtonVisibleShouldMatchPeekableView:(BOOL)match {
    %orig;
    if (UseBottomQualityButton())
        self.qualityButton.alpha = visible ? 1 : 0;
}

- (void)layoutSubviews {
    %orig;
    if (!UseBottomQualityButton()) return;
    CGFloat multiFeedWidth = [self respondsToSelector:@selector(multiFeedElementView)] ? [self multiFeedElementView].frame.size.width : 0;
    YTQTMButton *enter = [self enterFullscreenButton];
    BOOL youMuteInstalled = [self respondsToSelector:@selector(muteButton)];
    CGFloat shift = youMuteInstalled ? 40 : 0;
    if ([enter yt_isVisible]) {
        CGRect frame = enter.frame;
        frame.origin.x -= multiFeedWidth + enter.frame.size.width + 16 + shift;
        self.qualityButton.frame = frame;
    } else {
        YTQTMButton *exit = [self exitFullscreenButton];
        if ([exit yt_isVisible]) {
            CGRect frame = exit.frame;
            frame.origin.x -= multiFeedWidth + exit.frame.size.width + 16 + shift;
            self.qualityButton.frame = frame;
        }
    }
}

%new(v@:@)
- (void)updateYouQualityButton:(id)arg {
    [self.qualityButton setImage:qualityImage(currentQualityLabel) forState:0];
}

%new(v@:@)
- (void)didPressYouQuality:(id)arg {
    YTMainAppVideoPlayerOverlayViewController *c = [self.delegate valueForKey:@"_delegate"];
    [c didPressVideoQuality:arg];
    [self updateYouQualityButton:nil];
}

%end

%end

%group Settings

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound)
        [mutableOrder insertObject:@(YouQualitySection) atIndex:insertIndex + 1];
    return mutableOrder;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYouQualitySectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = YouQualityBundle();
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];
    YTSettingsSectionItem *master = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"ENABLED")
        titleDescription:nil
        accessibilityIdentifier:nil
        switchOn:TweakEnabled()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:EnabledKey];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:master];
    YTSettingsSectionItem *position = [YTSettingsSectionItemClass itemWithTitle:LOC(@"POSITION")
        accessibilityIdentifier:nil
        detailTextBlock:^NSString *() {
            return QualityButtonPosition() ? LOC(@"BOTTOM") : LOC(@"TOP");
        }
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSArray <YTSettingsSectionItem *> *rows = @[
                [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"TOP") titleDescription:LOC(@"TOP_DESC") selectBlock:^BOOL (YTSettingsCell *top, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:PositionKey];
                    [settingsViewController reloadData];
                    return YES;
                }],
                [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"BOTTOM") titleDescription:LOC(@"BOTTOM_DESC") selectBlock:^BOOL (YTSettingsCell *bottom, NSUInteger arg1) {
                    [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:PositionKey];
                    [settingsViewController reloadData];
                    return YES;
                }]
            ];
            YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"POSITION") pickerSectionTitle:nil rows:rows selectedItemIndex:QualityButtonPosition() parentResponder:[self parentResponder]];
            [settingsViewController pushViewController:picker];
            return YES;
        }];
    [sectionItems addObject:position];
    [settingsViewController setSectionItems:sectionItems forCategory:YouQualitySection title:@"YouQuality" titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YouQualitySection) {
        [self updateYouQualitySectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

%end

%ctor {
    %init(Settings);
    %init(Video);
    %init(Top);
    %init(Bottom);
}
