//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "SRGMediaPlayerController.h"

#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

// Forward declarations
@protocol SRGTimeSliderDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 *  The slider knob position when a live stream is played (the knob itself cannot be moved). The default value is left,
 *  as for the standard iOS playback controller.
 */
typedef __TVOS_PROHIBITED NS_ENUM(NSInteger, SRGTimeSliderLiveKnobPosition) {
    SRGTimeSliderLiveKnobPositionDefault = 0,
    SRGTimeSliderLiveKnobPositionLeft = SRGTimeSliderLiveKnobPositionDefault,
    SRGTimeSliderLiveKnobPositionRight
};

/**
 *  A slider displaying the playback position of the associated media player controller (with optional time and remaining
 *  time labels) and providing a way to seek to any position. The slider also display which part of the media has already
 *  been buffered.
 *
 *  Simply install an instance somewhere onto your custom player interface and bind to a media player controller. You
 *  can also bind two labels for displaying the time and the remaining time.
 *
 *  Slider colors can be customized as follows:
 *    - `minimumTrackTintColor`: Elapsed time track color (defaults to white).
 *    - `maximumTrackTintColor`: Remaining time track color (defaults to black).
 *    - `thumbTintColor`: Thumb color (defaults to white).
 */
__TVOS_PROHIBITED
@interface SRGTimeSlider : UISlider

/**
 *  The playback controller attached to the slider.
 */
@property (nonatomic, weak, nullable) IBOutlet SRGMediaPlayerController *mediaPlayerController;

/**
 *  The delegate receiving slider events.
 */
@property (nonatomic, weak, nullable) IBOutlet id<SRGTimeSliderDelegate> delegate;

/**
 *  Outlet which must be bound to the label displaying the remaining time.
 */
@property (nonatomic, weak, nullable) IBOutlet UILabel *timeLeftValueLabel;

/**
 *  Outlet which must be bound to the label displaying the current time.
 */
@property (nonatomic, weak, nullable) IBOutlet UILabel *valueLabel;

/**
 *  The thickness of the slider track. Defaults to 3, minimum is 1.
 */
@property (nonatomic) IBInspectable CGFloat trackThickness;

/**
 *  Buffering bar color (defaults to dark gray).
 */
@property (nonatomic, null_resettable) IBInspectable UIColor *bufferingTrackColor;

/**
 *  The time corresponding to the current slider position.
 *
 *  @discussion While dragging, this property may not reflect the value current time property of the asset being played.
 *              The slider `time` property namely reflects the current slider knob position, not the actual player
 *              position.
 */
@property (nonatomic, readonly) CMTime time;

/**
 *  For DVR and live streams, returns the date corresponding to the current slider position. If the date cannot be
 *  determined or for on-demand streams, the method returns `nil`.
 */
@property (nonatomic, readonly, nullable) NSDate *date;

/**
 *  Return `YES` iff the current slider position matches the conditions of a live feed.
 *
 *  @discussion While dragging, this property may not reflect the value returned by the media player controller `live` 
 *              property. The slider `live` property namely reflects the current slider knob position, not the actual 
 *              player position.
 */
@property (nonatomic, readonly, getter=isLive) BOOL live;

/**
 *  Set to `YES` to have the player seek when the slider knob is moved, or to `NO` if seeking must be performed only
 *  after the knob has been released.
 *
 *  Defaults to `YES`.
 */
@property (nonatomic, getter=isSeekingDuringTracking) IBInspectable BOOL seekingDuringTracking;

/**
 *  Set to `YES` to have the player automatically resume after a seek (if paused).
 *
 *  Defaults to `NO`.
 */
@property (nonatomic, getter=isResumingAfterSeek) IBInspectable BOOL resumingAfterSeek;

/**
 *  The position of the slider knob when playing a livestream. Defaults to `SRGTimeSliderLiveKnobPositionDefault`.
 */
@property (nonatomic) SRGTimeSliderLiveKnobPosition knobLivePosition;

@end

/**
 *  Delegate protocol.
 */
__TVOS_PROHIBITED
@protocol SRGTimeSliderDelegate <NSObject>

@optional

/**
 *  Called when the slider is moved, either interactively or as the result of normal playback.
 *
 *  @param slider      The slider for which the call is made.
 *  @param time        The time at which the slider was moved.
 *  @param value       The corresponding slider value (in seconds).
 *  @param interactive Whether the change is a result of a user interfaction (`YES`) or not.
 */
- (void)timeSlider:(SRGTimeSlider *)slider isMovingToPlaybackTime:(CMTime)time withValue:(float)value interactive:(BOOL)interactive;

/**
 *  Called when the user starts dragging the slider.
 */
- (void)timeSlider:(SRGTimeSlider *)slider didStartDraggingAtTime:(CMTime)time;

/**
 *  Called when the user stopped dragging the slider.
 */
- (void)timeSlider:(SRGTimeSlider *)slider didStopDraggingAtTime:(CMTime)time;

/**
 *  Implement to customise the value displayed by the slider `valueLabel`. If not implemented, a default presentation
 *  is used.
 *
 *  @param slider The slider for which the call is made.
 *  @param value  The corresponding slider value (in seconds).
 *  @param time   The corresponding time.
 */
- (nullable NSAttributedString *)timeSlider:(SRGTimeSlider *)slider labelForValue:(float)value time:(CMTime)time;

/**
 *  Implement to customise the accessibility label attached to `valueLabel`. If this method is not implemented,
 *  the `-timeSlider:labelForValue:time:` label is used, otherwise a default label.
 *
 *  @param slider The slider for which the call is made.
 *  @param value  The corresponding slider value (in seconds).
 *  @param time   The corresponding time.
 *
 *  @discussion This method is only called if `-timeSlider:labelForValue:time:` has been implemented.
 */
- (nullable NSString *)timeSlider:(SRGTimeSlider *)slider accessibilityLabelForValue:(float)value time:(CMTime)time;

/**
 *  Implement to customise the value displayed by the slider `timeLeftValueLabel`. If not implemented, a default presentation
 *  is used.
 *
 *  @param slider The slider for which the call is made.
 *  @param value  The corresponding slider value (in seconds).
 *  @param time   The corresponding time.
 */
- (nullable NSAttributedString *)timeSlider:(SRGTimeSlider *)slider timeLeftLabelForValue:(float)value time:(CMTime)time;

/**
 *  Implement to customise the accessibility label attached to `timeLeftValueLabel`. If this method is not implemented,
 *  the `-timeSlider:timeLeftLabelForValue:time:` label is used, otherwise a default label.
 *
 *  @param slider The slider for which the call is made.
 *  @param value  The corresponding slider value (in seconds).
 *
 *  @discussion This method is only called if `-timeSlider:timeLeftAccessibilityLabelForValue:time:` has been implemented.
 */
- (nullable NSString *)timeSlider:(SRGTimeSlider *)slider timeLeftAccessibilityLabelForValue:(float)value time:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
