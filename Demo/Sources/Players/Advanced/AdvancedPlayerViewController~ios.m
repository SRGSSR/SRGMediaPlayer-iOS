//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "AdvancedPlayerViewController.h"

#import "Resources.h"

#import <libextobjc/libextobjc.h>
#import <MAKVONotificationCenter/MAKVONotificationCenter.h>
#import <SRGMediaPlayer/SRGMediaPlayer.h>

const NSInteger kBackwardSkipInterval = 15.;
const NSInteger kForwardSkipInterval = 15.;

// To keep the view controller when picture in picture is active
static AdvancedPlayerViewController *s_advancedPlayerViewController;

@interface AdvancedPlayerViewController () <AVPictureInPictureControllerDelegate, SRGTracksButtonDelegate>

@property (nonatomic) Media *media;

@property (nonatomic, weak) IBOutlet SRGMediaPlayerController *mediaPlayerController;     // top-level object, retained

@property (nonatomic, weak) IBOutlet SRGPlaybackButton *playbackButton;
@property (nonatomic, weak) IBOutlet SRGTimeSlider *timeSlider;
@property (nonatomic, weak) IBOutlet UIButton *skipBackwardButton;
@property (nonatomic, weak) IBOutlet UIButton *skipForwardButton;

@property (nonatomic, weak) IBOutlet UIImageView *errorImageView;
@property (nonatomic, weak) IBOutlet UIImageView *audioOnlyImageView;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *loadingActivityIndicatorView;

@property (nonatomic) IBOutletCollection(UIView) NSArray *overlayViews;

@property (nonatomic) NSTimer *inactivityTimer;

@end

@implementation AdvancedPlayerViewController {
@private
    BOOL _userInterfaceHidden;
}

#pragma mark Object lifecycle

- (instancetype)initWithMedia:(Media *)media
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:ResourceNameForUIClass(self.class) bundle:nil];
    AdvancedPlayerViewController *viewController = [storyboard instantiateInitialViewController];
    viewController.media = media;
    return viewController;
}

#pragma mark Getters and setters

- (void)setInactivityTimer:(NSTimer *)inactivityTimer
{
    [_inactivityTimer invalidate];
    _inactivityTimer = inactivityTimer;
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.playbackButton.playImage = [UIImage imageNamed:@"play"];
    self.playbackButton.pauseImage = [UIImage imageNamed:@"pause"];
    
    self.errorImageView.hidden = YES;
    self.audioOnlyImageView.hidden = YES;
    
    // Workaround UIImage view tint color bug
    // See http://stackoverflow.com/a/26042893/760435
    UIImage *errorImage = self.errorImageView.image;
    self.errorImageView.image = nil;
    self.errorImageView.image = errorImage;
    
    UIImage *audioOnlyImage = self.audioOnlyImageView.image;
    self.audioOnlyImageView.image = nil;
    self.audioOnlyImageView.image = audioOnlyImage;
    
    SRGMediaPlayerView *playerView = self.mediaPlayerController.view;
    playerView.viewMode = self.media.is360 ? SRGMediaPlayerViewModeMonoscopic : SRGMediaPlayerViewModeFlat;
    
    UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    [playerView addGestureRecognizer:doubleTapGestureRecognizer];
    
    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [singleTapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];
    [playerView addGestureRecognizer:singleTapGestureRecognizer];
    
    SRGActivityGestureRecognizer *activityGestureRecognizer = [[SRGActivityGestureRecognizer alloc] initWithTarget:self action:@selector(resetInactivityTimer:)];
    activityGestureRecognizer.delegate = self;
    [self.view addGestureRecognizer:activityGestureRecognizer];
    
    // The frame of an activity indicator cannot be changed. Use a transform.
    self.loadingActivityIndicatorView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);
    [self.loadingActivityIndicatorView startAnimating];
    
    for (UIView *view in self.overlayViews) {
        view.layer.cornerRadius = 10.f;
        view.clipsToBounds = YES;
    }
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackStateDidChange:)
                                               name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                             object:self.mediaPlayerController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(playbackDidFail:)
                                               name:SRGMediaPlayerPlaybackDidFailNotification
                                             object:self.mediaPlayerController];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(accessibilityVoiceOverStatusChanged:)
                                               name:UIAccessibilityVoiceOverStatusChanged
                                             object:nil];
    
    @weakify(self)
    self.mediaPlayerController.pictureInPictureControllerCreationBlock = ^(AVPictureInPictureController *pictureInPictureController) {
        @strongify(self)
        pictureInPictureController.delegate = self;
    };
    
    [self.mediaPlayerController addObserver:self keyPath:@keypath(SRGMediaPlayerController.new, mediaType) options:0 block:^(MAKVONotification *notification) {
        @strongify(self)
        [self updateAudioOnlyUserInterface];
    }];
    [self.mediaPlayerController addObserver:self keyPath:@keypath(SRGMediaPlayerController.new, player.externalPlaybackActive) options:0 block:^(MAKVONotification * _Nonnull notification) {
        @strongify(self)
        [self updateAudioOnlyUserInterface];
    }];
    [self updateAudioOnlyUserInterface];
    
    [self.mediaPlayerController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1., NSEC_PER_SEC) queue: NULL usingBlock:^(CMTime time) {
        @strongify(self)
        [self updateSkipButtons];
    }];
    [self updateSkipButtons];
    
    [self updateMainPlaybackControls];
    [self updateInterfaceForControlsHidden:NO];
    [self restartInactivityTracker];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.movingToParentViewController || self.beingPresented) {
        if (! self.mediaPlayerController.pictureInPictureController.pictureInPictureActive) {
            [self.mediaPlayerController playURL:self.media.URL];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.movingToParentViewController || self.beingPresented) {
        if (self.mediaPlayerController.pictureInPictureController.pictureInPictureActive) {
            [self.mediaPlayerController.pictureInPictureController stopPictureInPicture];
        }
    }
    
    if (@available(iOS 11, *)) {
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self stopInactivityTracker];
    }
}

#pragma mark Status bar

- (BOOL)prefersStatusBarHidden
{
    return _userInterfaceHidden;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

#pragma mark Home indicator

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return _userInterfaceHidden && self.mediaPlayerController.mediaType == SRGMediaPlayerMediaTypeVideo;
}

#pragma mark UI

- (void)updateMainPlaybackControls
{
    SRGMediaPlayerPlaybackState playbackState = self.mediaPlayerController.playbackState;
    switch (playbackState) {
        case SRGMediaPlayerPlaybackStateIdle: {
            self.timeSlider.timeLeftValueLabel.hidden = YES;
            self.timeSlider.valueLabel.hidden = YES;
            self.loadingActivityIndicatorView.hidden = YES;
            break;
        }
            
        case SRGMediaPlayerPlaybackStatePreparing: {
            self.timeSlider.timeLeftValueLabel.hidden = YES;
            self.timeSlider.valueLabel.hidden = YES;
            self.loadingActivityIndicatorView.hidden = NO;
            break;
        }
            
        case SRGMediaPlayerPlaybackStateStalled: {
            self.timeSlider.timeLeftValueLabel.hidden = NO;
            self.timeSlider.valueLabel.hidden = YES;
            self.loadingActivityIndicatorView.hidden = NO;
            break;
        }
            
        default: {
            self.timeSlider.timeLeftValueLabel.hidden = NO;
            self.timeSlider.valueLabel.hidden = NO;
            self.loadingActivityIndicatorView.hidden = YES;
            break;
        }
    }
    
    [self updateSkipButtons];
}

- (void)updateAudioOnlyUserInterface
{
    if (self.mediaPlayerController.mediaType == SRGMediaPlayerMediaTypeAudio) {
        self.audioOnlyImageView.hidden = AVAudioSession.srg_isAirPlayActive;
    }
    else {
        self.audioOnlyImageView.hidden = YES;
    }
}

- (void)updateSkipButtons
{
    self.skipForwardButton.hidden = ! [self canSkipForward];
    self.skipBackwardButton.hidden = ! [self canSkipBackward];
}

- (void)restartInactivityTracker
{
    if (! UIAccessibilityIsVoiceOverRunning()) {
        self.inactivityTimer = [NSTimer timerWithTimeInterval:5.
                                                       target:self
                                                     selector:@selector(updateForInactivity:)
                                                     userInfo:nil
                                                      repeats:NO];
        self.inactivityTimer.tolerance = 0.5;
        [[NSRunLoop mainRunLoop] addTimer:self.inactivityTimer forMode:NSRunLoopCommonModes];
    }
    else {
        self.inactivityTimer = nil;
    }
}

- (void)stopInactivityTracker
{
    self.inactivityTimer = nil;
}

- (void)setUserInterfaceHidden:(BOOL)hidden animated:(BOOL)animated
{
    void (^animations)(void) = ^{
        [self updateInterfaceForControlsHidden:hidden];
    };
    
    _userInterfaceHidden = hidden;
    
    if (animated) {
        [self.view layoutIfNeeded];
        [UIView animateWithDuration:0.2 animations:^{
            animations();
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            if (@available(iOS 11, *)) {
                [self setNeedsUpdateOfHomeIndicatorAutoHidden];
            }
        }];
    }
    else {
        animations();
    }
}

- (void)updateInterfaceForControlsHidden:(BOOL)hidden
{
    [self setNeedsStatusBarAppearanceUpdate];
    
    for (UIView *view in self.overlayViews) {
        view.alpha = (hidden && self.mediaPlayerController.mediaType == SRGMediaPlayerMediaTypeVideo) ? 0.f : 1.f;
    }
}

#pragma mark Skips

- (BOOL)canSkipBackward
{
    return [self canSkipFromTime:[self seekStartTime] withInterval:-kBackwardSkipInterval];
}

- (BOOL)canSkipForward
{
    return [self canSkipFromTime:[self seekStartTime] withInterval:kForwardSkipInterval];
}

- (void)skipBackwardWithCompletionHandler:(void (^)(BOOL finished))completionHandler
{
    [self skipFromTime:[self seekStartTime] withInterval:-kBackwardSkipInterval completionHandler:completionHandler];
}

- (void)skipForwardWithCompletionHandler:(void (^)(BOOL finished))completionHandler
{
    [self skipFromTime:[self seekStartTime] withInterval:kForwardSkipInterval completionHandler:completionHandler];
}

- (CMTime)seekStartTime
{
    return CMTIME_IS_INDEFINITE(self.mediaPlayerController.seekTargetTime) ? self.mediaPlayerController.currentTime : self.mediaPlayerController.seekTargetTime;
}

- (BOOL)canSkipFromTime:(CMTime)time withInterval:(NSTimeInterval)interval
{
    if (CMTIME_IS_INDEFINITE(time)) {
        return NO;
    }
    
    SRGMediaPlayerController *mediaPlayerController = self.mediaPlayerController;
    SRGMediaPlayerPlaybackState playbackState = mediaPlayerController.playbackState;
    
    if (playbackState == SRGMediaPlayerPlaybackStateIdle || playbackState == SRGMediaPlayerPlaybackStatePreparing) {
        return NO;
    }
    
    SRGMediaPlayerStreamType streamType = mediaPlayerController.streamType;
    if (interval <= 0) {
        return (streamType == SRGMediaPlayerStreamTypeOnDemand || streamType == SRGMediaPlayerStreamTypeDVR);
    }
    else {
        return CMTIME_COMPARE_INLINE(CMTimeAdd(time, CMTimeMakeWithSeconds(interval, NSEC_PER_SEC)), <=, CMTimeRangeGetEnd(mediaPlayerController.timeRange));
    }
}

- (void)skipFromTime:(CMTime)time withInterval:(NSTimeInterval)interval completionHandler:(void (^)(BOOL finished))completionHandler
{
    if (! [self canSkipFromTime:time withInterval:interval]) {
        completionHandler ? completionHandler(NO) : nil;
        return;
    }
    
    CMTime targetTime = CMTimeAdd(time, CMTimeMakeWithSeconds(interval, NSEC_PER_SEC));
    [self.mediaPlayerController seekToPosition:[SRGPosition positionAroundTime:targetTime] withCompletionHandler:^(BOOL finished) {
        if (finished) {
            [self.mediaPlayerController play];
        }
        completionHandler ? completionHandler(finished) : nil;
    }];
}

#pragma mark AVPictureInPictureControllerDelegate protocol

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    s_advancedPlayerViewController = self;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    if (s_advancedPlayerViewController) {
        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        [rootViewController presentViewController:s_advancedPlayerViewController animated:YES completion:^{
            completionHandler(YES);
            s_advancedPlayerViewController = nil;
        }];
    }
    else {
        completionHandler(NO);
    }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    // Reset the status of the player when picture in picture is exited anywhere except from the SRGMediaPlayerViewController
    // itself
    if (s_advancedPlayerViewController && ! s_advancedPlayerViewController.presentingViewController) {
        [self.mediaPlayerController reset];
        s_advancedPlayerViewController = nil;
    }
}

#pragma mark SRGTracksButtonDelegate protocol

- (void)tracksButtonWillShowTrackSelection:(SRGTracksButton *)tracksButton
{
    [self stopInactivityTracker];
}

- (void)tracksButtonDidHideTrackSelection:(SRGTracksButton *)tracksButton
{
    [self restartInactivityTracker];
}

#pragma mark UIGestureRecognizerDelegate protocol

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [gestureRecognizer isKindOfClass:SRGActivityGestureRecognizer.class];
}

#pragma mark Notifications

- (void)playbackStateDidChange:(NSNotification *)notification
{
    SRGMediaPlayerController *mediaPlayerController = notification.object;
    
    if (mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStateEnded) {
        [self updateInterfaceForControlsHidden:NO];
    }
    else {
        if (mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStatePreparing) {
            self.errorImageView.hidden = YES;
        }
        [self updateMainPlaybackControls];
    }
}

- (void)playbackDidFail:(NSNotification *)notification
{
    self.errorImageView.hidden = NO;
    [self updateMainPlaybackControls];
}

- (void)accessibilityVoiceOverStatusChanged:(NSNotification *)notification
{
    [self restartInactivityTracker];
}

#pragma mark Actions

- (IBAction)skipForward:(id)sender
{
    [self skipForwardWithCompletionHandler:nil];
}

- (IBAction)skipBackward:(id)sender
{
    [self skipBackwardWithCompletionHandler:nil];
}

- (IBAction)dismiss:(id)sender
{
    if (! self.mediaPlayerController.pictureInPictureController.isPictureInPictureActive) {
        [self.mediaPlayerController reset];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Gesture recognizers

- (void)handleSingleTap:(UIGestureRecognizer *)gestureRecognizer
{
    [self restartInactivityTracker];
    [self setUserInterfaceHidden:! _userInterfaceHidden animated:YES];
}

- (void)handleDoubleTap:(UIGestureRecognizer *)gestureRecognizer
{
    AVPlayerLayer *playerLayer = self.mediaPlayerController.playerLayer;
    
    if ([playerLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    else {
        playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
}

- (void)resetInactivityTimer:(UIGestureRecognizer *)gestureRecognizer
{
    [self restartInactivityTracker];
}

#pragma mark Timers

- (void)updateForInactivity:(NSTimer *)timer
{
    [self setUserInterfaceHidden:YES animated:YES];
}

@end
