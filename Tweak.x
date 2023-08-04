#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import "../YouTubeHeader/YTColor.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h"
#import "../YouTubeHeader/YTSingleVideoController.h"
#import "../YouTubeHeader/MLFormat.h"

#define TweakKey @"YouQuality"

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

NSString *YouQualityUpdateNotification = @"YouQualityUpdateNotification";
NSString *currentQualityLabel = @"na";

NSBundle *YouQualityBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakKey ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakKey]];
    });
    return bundle;
}

static UIImage *qualityImage(NSString *qualityLabel) {
    return [%c(QTMIcon) tintImage:[UIImage imageNamed:qualityLabel inBundle:YouQualityBundle() compatibleWithTraitCollection:nil] color:[%c(YTColor) white1]];
}

%group Video

NSString *getVideoQuality(NSString *label) {
    if ([label hasPrefix:@"2160p"] && ![label isEqualToString:@"2160p60"])
        return @"2160p";
    if ([label hasPrefix:@"1440p"] && ![label isEqualToString:@"1440p60"])
        return @"1440p";
    if ([label hasPrefix:@"1080p"] && ![label isEqualToString:@"1080p60"])
        return @"1080p";
    if ([label hasPrefix:@"720p"] && ![label isEqualToString:@"720p60"])
        return @"720p";
    return label;
}

%hook YTSingleVideoController

- (void)playerItem:(id)playerItem didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = getVideoQuality([format qualityLabel]);
    [[NSNotificationCenter defaultCenter] postNotificationName:YouQualityUpdateNotification object:nil];
    %orig;
}

%end

%end

%group Top

%hook YTMainAppControlsOverlayView

%property (retain, nonatomic) YTQTMButton *qualityButton;

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    self.qualityButton = [self createButton:TweakKey accessibilityLabel:@"Quality" selector:@selector(didPressYouQuality:)];
     [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouQualityButton:) name:YouQualityUpdateNotification object:nil];
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    self.qualityButton = [self createButton:TweakKey accessibilityLabel:@"Quality" selector:@selector(didPressYouQuality:)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouQualityButton:) name:YouQualityUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.qualityButton : %orig;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? qualityImage(currentQualityLabel) : %orig;
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
    self.qualityButton = [self createButton:TweakKey accessibilityLabel:@"Quality" selector:@selector(didPressYouQuality:)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateYouQualityButton:) name:YouQualityUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (YTQTMButton *)button:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? self.qualityButton : %orig;
}

- (UIImage *)buttonImage:(NSString *)tweakId {
    return [tweakId isEqualToString:TweakKey] ? qualityImage(currentQualityLabel) : %orig;
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

%ctor {
    initYTVideoOverlay(TweakKey);
    %init(Video);
    %init(Top);
    %init(Bottom);
}
