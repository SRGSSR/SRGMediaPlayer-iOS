//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGTimeSlider.h"

#import "CMTimeRange+SRGMediaPlayer.h"
#import "NSBundle+SRGMediaPlayer.h"
#import "UIBezierPath+SRGMediaPlayer.h"

#import <libextobjc/libextobjc.h>

static void commonInit(SRGTimeSlider *self);

static NSString *SRGTimeSliderFormatter(NSTimeInterval seconds)
{
    NSCAssert(seconds >= 0, @"A non-negative number of seconds is expected");
    
    if (fabs(seconds) < 60. * 60.) {
        static NSDateComponentsFormatter *s_dateComponentsFormatter;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
            s_dateComponentsFormatter.allowedUnits = NSCalendarUnitSecond | NSCalendarUnitMinute;
            s_dateComponentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        });
        return [s_dateComponentsFormatter stringFromTimeInterval:seconds];
    }
    else {
        static NSDateComponentsFormatter *s_dateComponentsFormatter;
        static dispatch_once_t s_onceToken;
        dispatch_once(&s_onceToken, ^{
            s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
            s_dateComponentsFormatter.allowedUnits = NSCalendarUnitSecond | NSCalendarUnitMinute | NSCalendarUnitHour;
            s_dateComponentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        });
        return [s_dateComponentsFormatter stringFromTimeInterval:seconds];
    }
}

// Create a readable time for accessibility purposes
static NSString *SRGTimeSliderAccessibilityFormatter(NSTimeInterval seconds)
{
    if (isnan(seconds) || isinf(seconds)) {
        return nil;
    }
    
    static NSDateComponentsFormatter *s_dateComponentsFormatter;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        s_dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
        s_dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        s_dateComponentsFormatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    });
    
    return [s_dateComponentsFormatter stringFromTimeInterval:ABS(seconds)];
}

@interface SRGTimeSlider ()

@property (nonatomic, weak) id periodicTimeObserver;
@property (nonatomic) UIColor *overriddenThumbTintColor;
@property (nonatomic) UIColor *overriddenMaximumTrackTintColor;
@property (nonatomic) UIColor *overriddenMinimumTrackTintColor;

@property (nonatomic) NSArray<NSValue *> *previousLoadedTimeRanges;

@end

@implementation SRGTimeSlider

#pragma mark Object lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        commonInit(self);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        commonInit(self);
    }
    return self;
}

- (void)dealloc
{
    self.mediaPlayerController = nil;           // Unregister observers
}

#pragma mark Getters and setters

- (void)setMediaPlayerController:(SRGMediaPlayerController *)mediaPlayerController
{
    if (_mediaPlayerController) {
        [_mediaPlayerController removePeriodicTimeObserver:self.periodicTimeObserver];
        
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                                    object:_mediaPlayerController];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:SRGMediaPlayerSeekNotification
                                                    object:_mediaPlayerController];
    }
    
    _mediaPlayerController = mediaPlayerController;
    
    if (mediaPlayerController) {
        @weakify(self)
        self.periodicTimeObserver = [mediaPlayerController addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC) queue:NULL usingBlock:^(CMTime time) {
            @strongify(self)
            
            if (! self.tracking && mediaPlayerController.playbackState != SRGMediaPlayerPlaybackStateSeeking) {
                [self updateDisplayWithTime:time];
            }
        }];
        [self updateDisplayWithTime:mediaPlayerController.player.currentTime];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(srg_timeSlider_playbackStateDidChange:)
                                                   name:SRGMediaPlayerPlaybackStateDidChangeNotification
                                                 object:mediaPlayerController];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(srg_timeSlider_seek:)
                                                   name:SRGMediaPlayerSeekNotification
                                                 object:mediaPlayerController];
    }
}

- (BOOL)isDraggable
{
    // A slider knob can be dragged iff it corresponds to a valid range
    return self.minimumValue != self.maximumValue;
}

- (void)setTrackThickness:(CGFloat)trackThickness
{
    if (trackThickness >= 1.f) {
        _trackThickness = trackThickness;
    }
    else {
        _trackThickness = 1.f;
    }
}

- (void)setBufferingTrackColor:(UIColor *)bufferingTrackColor
{
    _bufferingTrackColor = bufferingTrackColor ?: UIColor.darkGrayColor;
}

// Override color properties since the default superclass behavior is to remove corresponding images, which we here
// already set in commonInit() and want to preserve

- (UIColor *)thumbTintColor
{
    return self.overriddenThumbTintColor ?: UIColor.whiteColor;
}

- (void)setThumbTintColor:(UIColor *)thumbTintColor
{
    self.overriddenThumbTintColor = thumbTintColor;
}

- (UIColor *)minimumTrackTintColor
{
    return self.overriddenMinimumTrackTintColor ?: UIColor.whiteColor;
}

- (void)setMinimumTrackTintColor:(UIColor *)minimumTrackTintColor
{
    self.overriddenMinimumTrackTintColor = minimumTrackTintColor;
}

- (UIColor *)maximumTrackTintColor
{
    return self.overriddenMaximumTrackTintColor ?: UIColor.blackColor;
}

- (void)setMaximumTrackTintColor:(UIColor *)maximumTrackTintColor
{
    self.overriddenMaximumTrackTintColor = maximumTrackTintColor;
}

#pragma mark Slider construction

// Take into account the non-standard smaller knob we installed in commonInit()

- (CGRect)minimumValueImageRectForBounds:(CGRect)bounds
{
    CGRect trackFrame = [super trackRectForBounds:self.bounds];
    CGRect thumbRect = [super thumbRectForBounds:self.bounds trackRect:trackFrame value:self.value];
    return CGRectMake(CGRectGetMinX(trackFrame),
                      CGRectGetMinY(trackFrame),
                      CGRectGetMidX(thumbRect) - CGRectGetMinX(trackFrame),
                      CGRectGetHeight(trackFrame));
}

- (CGRect)maximumValueImageRectForBounds:(CGRect)bounds
{
    CGRect trackFrame = [super trackRectForBounds:self.bounds];
    CGRect thumbRect = [super thumbRectForBounds:self.bounds trackRect:trackFrame value:self.value];
    return CGRectMake(CGRectGetMidX(thumbRect),
                      CGRectGetMinY(trackFrame),
                      CGRectGetMaxX(trackFrame) - CGRectGetMidX(thumbRect),
                      CGRectGetHeight(trackFrame));
}

#pragma mark Overrides

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    [super willMoveToWindow:newWindow];
    
    if (newWindow) {
        [self updateDisplayWithTime:self.time];
    }
}

#pragma mark Information display

- (void)updateDisplayWithTime:(CMTime)time
{
    CMTimeRange timeRange = [self.mediaPlayerController timeRange];
    if (self.mediaPlayerController.streamType == SRGMediaPlayerStreamTypeOnDemand && self.mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStateIdle) {
        self.maximumValue = 0.f;
        self.value = 0.f;
        self.userInteractionEnabled = YES;
    }
    else if (SRG_CMTIMERANGE_IS_NOT_EMPTY(timeRange) && SRG_CMTIMERANGE_IS_DEFINITE(timeRange)) {
        self.maximumValue = CMTimeGetSeconds(timeRange.duration);
        self.value = CMTimeGetSeconds(CMTimeSubtract(time, timeRange.start));
        self.userInteractionEnabled = YES;
    }
    else {
        float value = [self resetValue];
        self.maximumValue = value;
        self.value = value;
        self.userInteractionEnabled = NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(timeSlider:isMovingToPlaybackTime:withValue:interactive:)]) {
        [self.delegate timeSlider:self isMovingToPlaybackTime:time withValue:self.value interactive:NO];
    }
    
    [self setNeedsDisplay];
    [self updateTimeRangeLabelsWithTime:time];
}

- (CMTime)time
{
    CMTimeRange timeRange = self.mediaPlayerController.timeRange;
    if (CMTIMERANGE_IS_EMPTY(timeRange)) {
        return kCMTimeZero;
    }
    
    CMTime relativeTime = CMTimeMakeWithSeconds(self.value, NSEC_PER_SEC);
    return CMTimeAdd(timeRange.start, relativeTime);
}

- (NSDate *)date
{
    SRGMediaPlayerController *mediaPlayerController = self.mediaPlayerController;
    CMTimeRange timeRange = mediaPlayerController.timeRange;
    if (CMTIMERANGE_IS_INVALID(timeRange)) {
        return nil;
    }
    
    if (mediaPlayerController.streamType == SRGMediaPlayerStreamTypeLive) {
        return NSDate.date;
    }
    else if (mediaPlayerController.streamType == SRGMediaPlayerStreamTypeDVR) {
        return [NSDate dateWithTimeIntervalSinceNow:-CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(timeRange), self.time))];
    }
    else {
        return nil;
    }
}

- (BOOL)isLive
{
    // Live and timeshift feeds in live conditions. This happens when either the following condition
    // is met:
    //  - We have a pure live feed, which is characterized by an empty range
    //  - We have a timeshift feed, which is characterized by an indefinite player item duration, and whose slider knob is
    //    dragged close to now. We consider a timeshift 'close to now' when the slider is at the end, up to a tolerance
    return self.mediaPlayerController.streamType == SRGMediaPlayerStreamTypeLive
        || (self.mediaPlayerController.streamType == SRGMediaPlayerStreamTypeDVR && (self.maximumValue - self.value < self.mediaPlayerController.liveTolerance));
}

- (BOOL)isReadyToDisplayValues
{
    AVPlayerItem *playerItem = self.mediaPlayerController.player.currentItem;
    return (playerItem && self.mediaPlayerController.playbackState != SRGMediaPlayerPlaybackStateIdle
            && self.mediaPlayerController.playbackState != SRGMediaPlayerPlaybackStateEnded
            && playerItem.status == AVPlayerItemStatusReadyToPlay
            && self.mediaPlayerController.streamType != SRGMediaPlayerStreamTypeUnknown);
}

- (void)updateTimeRangeLabelsWithTime:(CMTime)time
{
    BOOL isReady = [self isReadyToDisplayValues];
    
    // Value label
    if ([self.delegate respondsToSelector:@selector(timeSlider:labelForValue:time:)]) {
        self.valueLabel.attributedText = [self.delegate timeSlider:self labelForValue:self.value time:time];
        
        if ([self.delegate respondsToSelector:@selector(timeSlider:accessibilityLabelForValue:time:)]) {
            self.valueLabel.accessibilityLabel = [self.delegate timeSlider:self accessibilityLabelForValue:self.value time:time];
        }
        else {
            self.valueLabel.accessibilityLabel = nil;
        }
    }
    else {
        if (isReady) {
            if (self.live) {
                self.valueLabel.text = SRGMediaPlayerNonLocalizedString(@"--:--");
                self.valueLabel.accessibilityLabel = nil;
            }
            else {
                self.valueLabel.text = SRGTimeSliderFormatter(self.value);
                self.valueLabel.accessibilityLabel = [NSString stringWithFormat:SRGMediaPlayerAccessibilityLocalizedString(@"%@ played", @"Label on slider for time elapsed"), SRGTimeSliderAccessibilityFormatter(self.value)];
            }
        }
        else {
            self.valueLabel.text = SRGMediaPlayerNonLocalizedString(@"--:--");
            self.valueLabel.accessibilityLabel = nil;
        }
    }
    
    // Time left label
    if ([self.delegate respondsToSelector:@selector(timeSlider:timeLeftLabelForValue:time:)]) {
        self.timeLeftValueLabel.attributedText = [self.delegate timeSlider:self timeLeftLabelForValue:self.value time:time];
        
        if ([self.delegate respondsToSelector:@selector(timeSlider:timeLeftAccessibilityLabelForValue:time:)]) {
            self.timeLeftValueLabel.accessibilityLabel = [self.delegate timeSlider:self timeLeftAccessibilityLabelForValue:self.value time:time];
        }
        else {
            self.timeLeftValueLabel.accessibilityLabel = nil;
        }
    }
    else {
        if (isReady) {
            if (self.live) {
                self.timeLeftValueLabel.text = SRGMediaPlayerLocalizedString(@"Live", @"Very short text on left time label when playing a live stream");
                self.timeLeftValueLabel.accessibilityLabel = nil;
            }
            else {
                self.timeLeftValueLabel.text = [NSString stringWithFormat:@"-%@", SRGTimeSliderFormatter(self.maximumValue - self.value)];
                self.timeLeftValueLabel.accessibilityLabel = [NSString stringWithFormat:SRGMediaPlayerAccessibilityLocalizedString(@"%@ remaining", @"Label on slider for time remaining"), SRGTimeSliderAccessibilityFormatter(self.value - self.maximumValue)];
            }
        }
        else {
            self.timeLeftValueLabel.text = SRGMediaPlayerNonLocalizedString(@"--:--");
            self.timeLeftValueLabel.accessibilityLabel = nil;
        }
    }
}

#pragma mark Touch handling

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    BOOL beginTracking = [super beginTrackingWithTouch:touch withEvent:event];
    if (! beginTracking || ! [self isDraggable]) {
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(timeSlider:didStartDraggingAtTime:)]) {
        [self.delegate timeSlider:self didStartDraggingAtTime:self.time];
    }
    
    return beginTracking;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    BOOL continueTracking = [super continueTrackingWithTouch:touch withEvent:event];
    
    CMTime time = self.time;
    
    if (continueTracking && [self isDraggable]) {
        [self updateTimeRangeLabelsWithTime:time];
        [self setNeedsDisplay];
    }
    
    if (self.seekingDuringTracking) {
        [self.mediaPlayerController seekToPosition:[SRGPosition positionAroundTime:time] withCompletionHandler:nil];
    }
    
    if ([self.delegate respondsToSelector:@selector(timeSlider:isMovingToPlaybackTime:withValue:interactive:)]) {
        [self.delegate timeSlider:self isMovingToPlaybackTime:time withValue:self.value interactive:YES];
    }
    
    return continueTracking;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if ([self isDraggable]) {
        [self.mediaPlayerController seekToPosition:[SRGPosition positionAroundTime:self.time] withCompletionHandler:^(BOOL finished) {
            if (self.resumingAfterSeek) {
                [self.mediaPlayerController play];
            }
        }];
    }
    
    if ([self.delegate respondsToSelector:@selector(timeSlider:didStopDraggingAtTime:)]) {
        [self.delegate timeSlider:self didStopDraggingAtTime:self.time];
    }
    
    [super endTrackingWithTouch:touch withEvent:event];
}

#pragma mark Images

- (UIImage *)emptyImage
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 2.f, 2.f)];
    UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, 0.f);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    [UIColor.clearColor set];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return viewImage;
}

- (UIImage *)thumbImage
{
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0.f, 0.f, 15.f, 15.f)];
    return [path srg_imageWithColor:self.thumbTintColor];
}

#pragma mark Drawing

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self drawMaximumTrack:context];
    [self drawMinimumTrack:context];
    
    void (^drawTimeRanges)(NSArray<NSValue *> *) = ^(NSArray<NSValue *> *timeRanges) {
        for (NSValue *value in timeRanges) {
            CMTimeRange timeRange = [value CMTimeRangeValue];
            [self drawBufferingTrackForRange:timeRange context:context];
        }
    };
    
    // In general, draw all loaded time ranges
    if (self.mediaPlayerController.playbackState != SRGMediaPlayerPlaybackStateSeeking) {
        NSArray<NSValue *> *loadedTimeRanges = self.mediaPlayerController.player.currentItem.loadedTimeRanges;
        drawTimeRanges(loadedTimeRanges);
        self.previousLoadedTimeRanges = loadedTimeRanges;
    }
    // If the player is seeking, find whether the player is seeking within one of the previous time ranges we
    // were displaying (though it might change during the seek). While this remains true, display the same ranges
    // as before (even if they are not perfectly up to date), so that the track never jumps erratically.
    else {
        for (NSValue *timeRange in self.previousLoadedTimeRanges) {
            if (CMTimeRangeContainsTime(timeRange.CMTimeRangeValue, self.time)) {
                drawTimeRanges(self.previousLoadedTimeRanges);
                return;
            }
        }
    }
}

- (void)drawMaximumTrack:(CGContextRef)context
{
    CGRect trackFrame = [self maximumValueImageRectForBounds:self.bounds];
    
    CGContextSetLineWidth(context, self.trackThickness);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, CGRectGetMinX(trackFrame), CGRectGetMidY(self.bounds));
    CGContextAddLineToPoint(context, CGRectGetMaxX(trackFrame), CGRectGetMidY(self.bounds));
    CGContextSetStrokeColorWithColor(context, self.maximumTrackTintColor.CGColor);
    CGContextStrokePath(context);
}

- (void)drawBufferingTrackForRange:(CMTimeRange)timeRange context:(CGContextRef)context
{
    CGFloat duration = CMTimeGetSeconds(self.mediaPlayerController.player.currentItem.duration);
    if (isnan(duration)) {
        return;
    }
    
    CGRect trackFrame = [self trackRectForBounds:self.bounds];
    
    CGFloat minX = CGRectGetMinX(trackFrame) + CGRectGetWidth(trackFrame) / duration * CMTimeGetSeconds(timeRange.start);
    CGFloat maxX = CGRectGetMinX(trackFrame) + CGRectGetWidth(trackFrame) / duration * CMTimeGetSeconds(CMTimeRangeGetEnd(timeRange));
    
    CGContextSetLineWidth(context, self.trackThickness);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, minX, CGRectGetMidY(self.bounds));
    CGContextAddLineToPoint(context, maxX, CGRectGetMidY(self.bounds));
    CGContextSetStrokeColorWithColor(context, self.bufferingTrackColor.CGColor);
    CGContextStrokePath(context);
}

- (void)drawMinimumTrack:(CGContextRef)context
{
    CGRect barFrame = [self minimumValueImageRectForBounds:self.bounds];
    
    CGContextSetLineWidth(context, self.trackThickness);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, CGRectGetMinX(barFrame), CGRectGetMidY(self.bounds));
    CGContextAddLineToPoint(context, CGRectGetWidth(barFrame), CGRectGetMidY(self.bounds));
    CGContextSetStrokeColorWithColor(context, self.minimumTrackTintColor.CGColor);
    CGContextStrokePath(context);
}

#pragma mark Helpers

- (float)resetValue
{
    return (self.knobLivePosition == SRGTimeSliderLiveKnobPositionLeft) ? 0.f : 1.f;
}

#pragma mark Notifications

- (void)srg_timeSlider_playbackStateDidChange:(NSNotification *)notification
{
    if (self.mediaPlayerController.playbackState == SRGMediaPlayerPlaybackStateIdle) {
        self.previousLoadedTimeRanges = nil;
        
        float value = [self resetValue];
        self.value = value;
        self.maximumValue = value;
        
        if ([self.delegate respondsToSelector:@selector(timeSlider:isMovingToPlaybackTime:withValue:interactive:)]) {
            [self.delegate timeSlider:self isMovingToPlaybackTime:self.time withValue:self.value interactive:NO];
        }
        
        [self setNeedsDisplay];
        [self updateTimeRangeLabelsWithTime:self.time];
    }
}

- (void)srg_timeSlider_seek:(NSNotification *)notification
{
    // Do not wait for playback to resume to update display, update to the target location of seeks
    CMTime time = [notification.userInfo[SRGMediaPlayerSeekTimeKey] CMTimeValue];
    [self updateDisplayWithTime:time];
}

#pragma mark Accessibility

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    if (! [self isReadyToDisplayValues]) {
        return SRGMediaPlayerAccessibilityLocalizedString(@"No playback", @"Slider label when nothing to play");
    }
    else if (self.live) {
        return SRGMediaPlayerAccessibilityLocalizedString(@"Live playback", @"Slider label when playing live");
    }
    else if (self.mediaPlayerController.streamType == SRGMediaPlayerStreamTypeDVR) {
        return [NSString stringWithFormat:SRGMediaPlayerAccessibilityLocalizedString(@"%@ from live", @"Slider label when playing a DVR in the past"),
                SRGTimeSliderAccessibilityFormatter(self.maximumValue - self.value)];
    }
    else {
        return [NSString stringWithFormat:SRGMediaPlayerAccessibilityLocalizedString(@"%@ played", @"Label on slider for time elapsed"), SRGTimeSliderAccessibilityFormatter(self.value)];
    }
}

- (NSString *)accessibilityValue
{
    if (self.live) {
        return nil;
    }
    else {
        return [super accessibilityValue];
    }
}

#pragma mark Interface Builder integration

- (void)prepareForInterfaceBuilder
{
    [super prepareForInterfaceBuilder];
    
    [self setNeedsDisplay];
}

@end

#pragma mark Static functions

static void commonInit(SRGTimeSlider *self)
{
    // Apply default colors
    self.bufferingTrackColor = nil;
    
    self.minimumValue = 0.f;                    // Always 0
    self.maximumValue = 0.f;
    self.value = 0.f;
    
    self.trackThickness = 3.f;
    
    UIImage *triangle = [self emptyImage];
    UIImage *image = [triangle resizableImageWithCapInsets:UIEdgeInsetsMake(1.f, 1.f, 1.f, 1.f)];
    
    [self setMinimumTrackImage:image forState:UIControlStateNormal];
    [self setMaximumTrackImage:image forState:UIControlStateNormal];
    
    [self setThumbImage:[self thumbImage] forState:UIControlStateNormal];
    [self setThumbImage:[self thumbImage] forState:UIControlStateHighlighted];
    
    self.seekingDuringTracking = YES;
    self.knobLivePosition = SRGTimeSliderLiveKnobPositionLeft;
}
