//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#import "SRGMediaPlayerConstants.h"
#import "SRGMediaPlayerView.h"
#import "SRGPosition.h"
#import "SRGSegment.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  The SRG Media Player library is a mid-level playback library based on `AVPlayer`. It is intended to lower the
 *  implementation costs usually associated with `AVPlayer`, while adding advanced capabilities and extensive
 *  support for all kinds of medias.
 *
 *  The library provides the following components:
 *    - A controller, `SRGMediaPlayerController`, to perform playback.
 *    - A view, `SRGMediaPlayerView`, with which content played by a controller can be displayed.
 *    - A set of overlays to create custom player user interfaces.
 *    - `SRGMediaPlayerViewController`, an `AVPlayerViewController` subclass using an `SRGMediaPlayerController` for
 *      playback. This class therefore provides a standard iOS / tvOS user experience which should fulfill most needs.
 *
 *  ## Controller
 *
 *  `SRGMediaPlayerController` manages the playback of a media from a network stream or a file. Unlike `AVPlayer`
 *  which can be quite tricky to use, `SRGMediaPlayerController` is intended to provide basic and advanced
 *  playback capabilities with low implementation cost:
 *    - Audio and video playback for all kinds of streams (on-demand, live, DVR).
 *    - Playback status information (mostly through notifications or KVO).
 *    - Media information extraction.
 *    - Background playback.
 *    - Simultaneous playback.
 *
 *  In addition, `SRGMediaPlayerController` optionally supports segments. A segment defined as part of a media, specified
 *  by a start time and a duration. Segments make it possible to add a logical structure on top of a media, e.g. topics
 *  in a news show, chapters in a movie, and so on. If segments are associated with the media being played, 
 *  `SRGMediaPlayerController` will:
 *    - Report transitions between segments when they occur (through notifications).
 *    - Skip segments which must must not be played (blocked segments).
 *
 *  ## View
 *
 *  `SRGMediaPlayerController` is a raw media player and is usually not used as is (though it could, for example
 *  when you only need to play audio files). Most of the time, though, you need to display the content being played.
 *  This is the role of `SRGMediaPlayerView`.
 *
 *  By default, a controller provides a lazily instantiated view which can be installed in a view hierarchy. You
 *  can also instantiate an `SRGMediaPlayerView` in a xib or storyboard and bind it to a controller if you prefer.
 *
 *  `SRGMediaPlayerView` supports standard video playback, as well as 360° video playback (with carboard support).
 *  The `viewMode` property can be used to choose how a video should be displayed.
 *
 *  ## Implementing a media player user interface
 *
 *  To implement your own custom media player user interface, you must create your own player class (most probably a view
 *  controller), and delegate playback to an `SRGMediaPlayerController` instance:
 *    - Instantiate `SRGMediaPlayerController` in your player implementation file. If you are using a storyboard or 
 *      a xib to define your player layout, you can also drop a plain object with Interface Builder and assign it the
 *      `SRGMediaPlayerController` class. Be sure to connect an outlet if you need to later refer to it from within
 *      your code.
 *    - When creating a video player, you must add the `view` property somewhere within your view hierarchy so that
 *      the content can be properly displayed:
 *        - If you are instantiating the controller in a storyboard or a nib, this is easily achieved by adding a view 
 *          with the `SRGMediaPlayerView` class to your layout, and binding it to the `view` property right from Interface
 *          Builder.
 *        - If you have instantiated `SRGMediaPlayerController` in code, then you must add the `view` property manually
 *          to your view hierarchy by calling `-[UIView addSubview:]` or one of the similar `UIView` methods. Be sure 
 *          to set constraints or autoresizing masks properly so that the view behaves as expected.
 *      If you only need to implement an audio player, you can skip this step.
 *    - Call one of the play methods to start playing your media.
 *
 *  You should now have a working implementation able to play audios or videos. There is no way for the user to pause
 *  playback or to seek within the media, though. The `SRGMediaPlayer` library provides a few standard controls and
 *   overlays with which you can easily add such functionalities to your custom player.
 *
 *  ## Controls and overlays
 *
 *  The `SRGMediaPlayer` library provides the following set of controls which can be easily connected to a media player
 *  controller instance to report its status or manage playback. On tvOS you should avoid creating a custom control
 *  layout, as the experience should be based on `SRGMediaPlayerViewController`. This is why most of the following controls
 *  are only available for iOS:
 *
 *  - Buttons:
 *    - `SRGPlaybackButton`: A button to pause or resume playback.
 *    - `SRGPictureInPictureButton`: A button to enter or leave picture in picture playback.
 *  - Sliders:
 *    - `SRGTimeSlider`: A slider to see the current playback progress, seek, and display the elapsed and remaining times.
 *    - `SRGVolumeView`: A slider to adjust the volume.
 *  - Miscellaneous:
 *    - `SRGPlaybackActivityIndicatorView`: An activity indicator displayed when the player is buffering or seeking.
 *    - `SRGAirPlayButton`: A button which is visible when AirPlay is available.
 *    - `SRGAirPlayView`: An overlay which is visible when external AirPlay playback is active, and which displays the
 *                        current route.
 *    - `SRGTimelineView`: A linear collection to display the segments associated with a media.
 *
 *  Customizing your player layout using the overlays above is straightforward:
 *    - Drop instances of the views you need onto your player layout (or instantiate them in code) and tweak their
 *      appearance.
 *    - Set their `mediaPlayerController` property to point at the underlying controller. If your controller was
 *      instantiated in a storyboard or a xib file, this can be entirely done in Interface Builder via ctrl-dragging.
 *
 *  To switch between available view modes available for a content (e.g. between 360° and cardboard modes), the library
 *  also provides `SRGViewModeButton`, which must be connected to a media player view directly.
 *
 *  Usually, you want to hide overlays after some user inactivity delay. While showing or hiding overlays is something
 *  your implementation is responsible of, the `SRGMediaPlayer` library provides the `SRGActivityGestureRecognizer`
 *  class to easily detect any kind of user activity. Just add this gesture recognizer on the view where you want
 *  to track user activity, and associate a corresponding action to show or hide the interface.
 *
 *  ## Player lifecycle
 *
 *  `SRGMediaPlayerController` is based around `AVPlayer`, which is publicly exposed as a `player` property. You should
 *  avoid controlling playback by acting on this `AVPlayer` instance directly, but you can still use it for any other
 *  purpose:
 *    - Information extraction (e.g. current `AVPlayerItem`, subtitles and audio channels).
 *    - Key-value observation of some other changes you might be interested in (e.g. IceCast / SHOUTcast information).
 *    - AirPlay setup.
 *    - Muting the player.
 *    - etc.
 *
 *  In the course of a controller lifetime, the `player` property might change several times, e.g. when a new media is
 *  played or when playback is stopped. Consequently, `SRGMediaPlayerController` provides lifecycle hooks so that you
 *  can reliably perform additional setup when the internal `AVPlayer` instance is created or destroyed. Those take the
 *  form of optional blocks to which the player is provided as parameter:
 *    - `playerCreationBlock`: This block is called right after player creation.
 *    - `playerDestructionBlock`: This block is called right before player destruction.
 *    - `playerConfigurationBlock`: Specific configuration block called when `-reloadPlayerConfiguration` is called. For
 *                                  consistency, this block is also called right after player creation as well.
 *
 *  ## Player events
 *
 *  The player emits notifications when important changes are detected:
 *    - Playback state changes and errors. Errors are defined in the `SRGMediaPlayerError.h` header file.
 *    - Segment changes and blocked segment skipping.
 *  For more information about the available notifications, have a look at the `SRGMediaPlayerConstants.h` header file.
 *
 *  Some controller properties (e.g. the `playbackState` property) are key-value observable. If not stated explicitly,
 *  KVO might be possible but is not guaranteed. You should in general listen to notifications, though, as they may
 *  convey additional useful information in their associated dictionary.
 *
 *  Note that all notifications and KVO changes are reported on the main thread.
 *
 *  ## Playback management
 *
 *  Several methods have been provided to start playback and pause it, or to seek to a specific time. You can also prepare
 *  the player in a paused state before actually starting playback when you want. As a general rule, play, pause and seek
 *  methods are player instructions to perform those operations: Depending on the state of the player, these operations
 *  are not guaranteed to succeed. In general, you should therefore observe player events, as describe above, for example
 *  when updating your user interface. You cannot namely assume the player will be playing right after `-play` has been
 *  called, for example (but you can still update your interface right after `-play` has been called, by checking the
 *  `playbackState` property). 
 *
 *  In some situations some behaviors can be guaranteed (e.g. when the player has successfully been prepared, calling
 *  `-play` will put it in the playing state immediately) but, in general, you should rely on the playback state property
 *  and respond to its changes.
 *
 *  ## Segments
 *
 *  When playing a media, an optional `segments` parameter can be provided. This parameter must be an array of objects
 *  conforming to the `SRGSegment` protocol. When segments have been supplied to the player, corresponding notifications
 *  will be emitted when segment transitions occur (see above). If you want to display segments, you can use the supplied
 *  `SRGTimelineView` or create your own view, as required by your application.
 *
 *  Overlapping segments are not supported, associated time ranges must be disjoint (the behavior is otherwise undefined).
 *
 *  ## Boundary time and periodic time observers
 *
 *  Three kinds of observers can be set on a player to observe its playback:
 *    - Usual boundary time and periodic time observers, which you define on the `AVPlayer` instance directly by accessing
 *      the `player` property. You should use the player creation and destruction blocks to install and remove them reliably.
 *    - `AVPlayer` periodic time observers only trigger when the player actually plays. In some cases, you still want to
 *      perform periodic updates even when playback is paused (e.g. updating the user interface while a DVR stream is paused).
 *      For such use cases, `SRGMediaPlayerController` provides the `-addPeriodicTimeObserverForInterval:queue:usingBlock:`
 *      method, with which such observers can be defined. These observers being managed by the controller, you can set them
 *      up right after controller creation if you like.
 *
 *  For more information about `AVPlayer` observers, please refer to the official Apple documentation.
 */
@interface SRGMediaPlayerController : NSObject

/**
 *  @name Settings
 */

/**
 *  The minimum window length which must be available for a stream to be considered to be a DVR stream, in seconds. The
 *  default value is 0. This setting can be used so that streams detected as DVR ones because their window is small can
 *  properly behave as live streams. This is useful to avoid usual related seeking issues, or slider hiccups during 
 *  playback near live conditions, most notably.
 */
@property (nonatomic) NSTimeInterval minimumDVRWindowLength;

/**
 *  Return the tolerance (in seconds) for a DVR stream to be considered being played in live conditions. If the stream
 *  playhead is located within the last `liveTolerance` seconds of the stream, it is considered to be live. The default 
 *  value is 30 seconds and matches the standard iOS player controller behavior.
 */
@property (nonatomic) NSTimeInterval liveTolerance;

/**
 *  The absolute tolerance (in seconds) applied when attempting to start playback near the end of a stream (or segment
 *  thereof). Default is 0 seconds.
 *
 *  @discussion If the distance between the desired playback position and the end is small according to `endTolerance`
 *              and / or `endToleranceRatio` (the smallest value wins), playback will start at the default position.
 */
@property (nonatomic) NSTimeInterval endTolerance;

/**
 *  The tolerance ratio applied when attempting to start playback near the end of a stream (or segment thereof). The
 *  ratio is multiplied with the stream (or segment) duration to calculate the tolerance in seconds. Default is 0.
 *
 *  @discussion If the distance between the desired playback position and the end is small according to `endTolerance`
 *              and / or `endToleranceRatio` (the smallest value wins), playback will start at the default position.
 */
@property (nonatomic) float endToleranceRatio;

/**
 *  The view where the player displays its content. Either install in your own view hierarchy, or bind a corresponding view
 *  with the `SRGMediaPlayerView` class in Interface Builder.
 */
@property (nonatomic, readonly, nullable) IBOutlet SRGMediaPlayerView *view;

@end

/**
 *  @name Player lifecycle
 */

@interface SRGMediaPlayerController (Lifecycle)

/**
 *  Optional block which gets called right after internal player creation (player changes from `nil` to not `nil`).
 *
 *  @discussion This block can be called several times over a controller lifetime.
 */
@property (nonatomic, copy, nullable) void (^playerCreationBlock)(AVPlayer *player);

/**
 *  Optional block which gets called right after internal player creation, when the player changes, or when the
 *  configuration is reloaded by calling `-reloadPlayerConfiguration`. Does not get called when the player is set to `nil`.
 */
@property (nonatomic, copy, nullable) void (^playerConfigurationBlock)(AVPlayer *player);

/**
 *  Optional block which gets called right before player destruction (player changes from not `nil` to `nil`).
 *
 *  @discussion This block can be called several times over a controller lifetime.
 */
@property (nonatomic, copy, nullable) void (^playerDestructionBlock)(AVPlayer *player);

/**
 *  Ask the player to reload its configuration by calling the associated configuration block, if any. Does nothing if
 *  the player has not been created yet.
 */
- (void)reloadPlayerConfiguration;

/**
 *  Reload the player configuration with a new configuration block. Any previously existing configuration block is
 *  replaced.
 *
 *  @discussion If the player has not been created yet, the block is set but not called.
 */
- (void)reloadPlayerConfigurationWithBlock:(nullable void (^)(AVPlayer *player))block;

/**
 *  @name Media configurationn (audio track and subtitle customization).
 */

/**
 *  Optional block which gets called once media information has been loaded, and which can be used to customize
 *  audio or subtitle selection, as well as subtitle appearance.
 */
@property (nonatomic, copy, nullable) void (^mediaConfigurationBlock)(AVPlayerItem *playerItem, AVAsset *asset);

/**
 *  Reload media configuration by calling the associated block, if any. Does nothing if the media has not been loaded
 *  yet. If there is no configuration block defined, calling this method applies the default selection options for
 *  audio and subtitles, and removes any subtitle styling which might have been applied.
 */
- (void)reloadMediaConfiguration;

/**
 *  Reload the player configuration with a new configuration block. Any previously existing configuration block is
 *  replaced.
 *
 *  @discussion If the media has not been loaded yet, the block is set but not called.
 */
- (void)reloadMediaConfigurationWithBlock:(nullable void (^)(AVPlayerItem *playerItem, AVAsset *asset))block;

@end

/**
 *  @name Playback
 */

@interface SRGMediaPlayerController (Playback)

/**
 *  Prepare to play the media, starting at the specified position, but with the player paused (if playback is not started
 *  in the completion handler). Segments can be optionally provided. If you want playback to start right after preparation, 
 *  call `-play` from the completion handler (in which case the player will immediately reach the playing state).
 *
 *  @param URL               The URL to play.
 *  @param position          The position to start at. If `nil` or if the specified position lies outside the media time
 *                           range, playback starts at the default position.
 *  @param segments          A segment list.
 *  @param userInfo          A dictionary to associate arbitrary information with the media being played (for later retrieval).
 *                           This information stays associated with the player controller until it is reset.
 *  @param completionHandler The completion block to be called after the player has finished preparing the media. This
 *                           block will only be called if the media could be loaded.
 *
 *  @discussion The player state is set to preparing during all the preparation phase (this is also the state on completion
 *              handler entry). The player state is not updated to paused until the completion handler has been executed.
 *              This way, any change to the player state in the completion handler (e.g. because of a `-play` request) will 
 *              only be reflected after the completion handler has been executed, so that the player transitions from preparing
 *              to this state without going through the paused state.
 *
 *              For an on-demand stream, the default position is its start, for DVR streams its end. When playing a DVR
 *              stream and the position is contained within the first chunk, playback might start at the end of the stream
 *              (iOS 11 and above) or at the specified position (older iOS versions).
 */
- (void)prepareToPlayURL:(NSURL *)URL
              atPosition:(nullable SRGPosition *)position
            withSegments:(nullable NSArray<id<SRGSegment>> *)segments
                userInfo:(nullable NSDictionary *)userInfo
       completionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Same as `-prepareToPlayURL:atPosition:withSegments:userInfo:completionHandler:`, but with a player asset.
 */
- (void)prepareToPlayURLAsset:(AVURLAsset *)URLAsset
                   atPosition:(nullable SRGPosition *)position
                 withSegments:(nullable NSArray<id<SRGSegment>> *)segments
                     userInfo:(nullable NSDictionary *)userInfo
            completionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Start playback. Does nothing if no content URL is attached to the controller.
 */
- (void)play;

/**
 *  Ask the player to pause playback.
 *
 *  @discussion See `-play`.
 */
- (void)pause;

/**
 *  Ask the player to stop playback. Call `-play` to restart playback with the same content URL, segments, start position
 *  and user info.
 */
- (void)stop;

/**
 *  Ask the player to seek to a given position. A paused player remains paused, while a playing player remains
 *  playing. You can use the completion handler to change the player state if needed, e.g. to automatically
 *  resume playback after a seek has been performed on a paused player.
 *
 *  @param position          The position to seek to. If `nil` or if the specified position lies outside the media time
 *                           range, seeking will be made to the nearest valid position.
 *  @param completionHandler The completion block called when the seek ends. If the seek has been interrupted by
 *                           another seek, the completion handler will be called with `finished` set to `NO`, otherwise 
 *                           with `finished` set to `YES`.
 *
 *  @discussion Upon completion handler entry, the playback state will be up-to-date if the seek finished, otherwise
 *              the player will still be in the seeking state. Note that if the media was not ready to play, seeking
 *              won't take place, and the completion handler won't be called.
 *
 *              If the specified position lies outside the media time range, the location at which playback actually
 *              resumes is undefined (depends on iOS versions).
 *
 *              Refer to `-[AVPlayer seekToTime:toleranceBefore:toleranceAfter:completionHandler:]` documentation
 *              for more information about seek tolerances. Attempting to seek to a blocked segment will skip the segment
 *              and resume after it.
 */
- (void)seekToPosition:(nullable SRGPosition *)position withCompletionHandler:(nullable void (^)(BOOL finished))completionHandler;

/**
 *  Reset the player to its original idle state with no media URL, segments or user info.
 *
 *  @discussion Periodic time observers registered with the controller are not unregistered.
 */
- (void)reset;

/**
 *  Arbitrary user info which has been associated with the media being played.
 *
 *  @discussion This information can be updated at any time, but is usually specified when a playback method is called.
 */
@property (nonatomic, nullable) NSDictionary *userInfo;

@end

/**
 *  @name Segments
 */

@interface SRGMediaPlayerController (Segments)

/**
 *  The segments which have been loaded into the player.
 *
 *  @discussion The segment list can be updated at any time.
 */
@property (nonatomic, nullable) NSArray<id<SRGSegment>> *segments;

/**
 *  The visible segments which have been loaded into the player.
 */
@property (nonatomic, readonly, nullable) NSArray<id<SRGSegment>> *visibleSegments;

/**
 *  Return the segment corresponding to the current playback position, `nil` if none.
 */
@property (nonatomic, readonly, weak, nullable) id<SRGSegment> currentSegment;

@end

/**
 *  @name Controller status information
 */

@interface SRGMediaPlayerController (Status)

/**
 *  The current state of the media player controller.
 *
 *  @discussion This property is key-value observable.
 */
@property (nonatomic, readonly) SRGMediaPlayerPlaybackState playbackState;

/**
 *  The URL of the content currently loaded into the player.
 */
@property (nonatomic, readonly, nullable) NSURL *contentURL;

/**
 *  The URL asset currently loaded into the player.
 */
@property (nonatomic, readonly, nullable) AVURLAsset *URLAsset;

/**
 *  The current media time range (might be empty or indefinite).
 *
 *  @discussion Use `CMTimeRange` macros for checking time ranges, see `CMTimeRange+SRGMediaPlayer.h`. For DVR
 *              streams with sliding windows, the range start can vary as the stream is played. For DVR streams
 *              with fixed start, the duration will vary instead.
 */
@property (nonatomic, readonly) CMTimeRange timeRange;

/**
 *  The current playback time.
 *
 *  @discussion Use `CMTime` macros for checking times, see `CMTime+SRGMediaPlayer.h`.
 */
@property (nonatomic, readonly) CMTime currentTime;

/**
 *  The time at which the player started seeking, `kCMTimeIndefinite` if no seek is currently being made.
 */
@property (nonatomic, readonly) CMTime seekStartTime;

/**
 *  The current time to which the player is seeking, `kCMTimeIndefinite` if no seek is currently being made.
 */
@property (nonatomic, readonly) CMTime seekTargetTime;

/**
 *  The media type (audio / video).
 */
@property (nonatomic, readonly) SRGMediaPlayerMediaType mediaType;

/**
 *  The stream type (live / DVR / VOD).
 */
@property (nonatomic, readonly) SRGMediaPlayerStreamType streamType;

/**
 *  For DVR and live streams, returns the date corresponding to the current playback time. If the date cannot be
 *  determined or for an on-demand stream, the method returns `nil`.
 */
@property (nonatomic, readonly, nullable) NSDate *date;

/**
 *  Return `YES` iff the stream is currently played in live conditions (@see `liveTolerance`).
 */
@property (nonatomic, readonly, getter=isLive) BOOL live;

@end

/**
 *  @name Time observers
 */

@interface SRGMediaPlayerController (TimeObservers)

/**
 *  Register a block for periodic execution when the player is not idle (unlike usual `AVPlayer` time observers which do
 *  not run when playback has been paused). This makes such observers very helpful when UI must be updated continously 
 *  when the player is up, for example in the case of paused DVR streams.
 *
 *  @param interval Time interval between block executions.
 *  @param queue    The serial queue onto which block should be enqueued (main queue if `NULL`).
 *  @param block	The block to be periodically executed.
 *
 *  @return The time observer. The observer is retained by the media player controller, you can store a weak reference
 *          to it and remove it at a later time if needed.
 *
 *  @discussion Your can registers observers with the media player controller when you like (you do not have to wait until the player
 *              is ready, observers will be attached to it automatically when appropriate). Note that such observers are not removed
 *              when the player controller is reset (they will not execute until playback is started again).
 */
- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(nullable dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))block;

/**
 *  Remove a time observer (does nothing if the observer is not registered).
 *
 *  @param observer The time observer to remove (does nothing if `nil`).
 */
- (void)removePeriodicTimeObserver:(nullable id)observer;

@end

/**
 *  @name Native player access
 */

@interface SRGMediaPlayerController (NativePlayer)

/**
 *  The underlying player. You can use it to extract playback information, set observers, or even alter the playback,
 *  though in general you should prefer the equivalent controller methods.
 *
 *
 *  Use the lifecycle block hooks (see below) to reliably access the player, as it might not always be available (e.g.
 *  when the controller is idle).
 */
@property (nonatomic, readonly, nullable) AVPlayer *player;

/**
 *  The layer used by the player. Use it if you need to change the content gravity or to detect when the player is ready
 *  for display.
 */
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;

@end

/**
 *  @name Playback (convenience methods)
 */

@interface SRGMediaPlayerController (Convenience)

/**
 *  Prepare to play a URL, starting at the default position.
 *
 *  For more information, @see `-prepareToPlayURL:atPosition:withSegments:userInfo:completionHandler:`.
 */
- (void)prepareToPlayURL:(NSURL *)URL withCompletionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Prepare to play an asset, starting at the default position.
 *
 *  For more information, @see `-prepareToPlayURLAsset:atPosition:withSegments:userInfo:completionHandler:`.
 */
- (void)prepareToPlayURLAsset:(AVURLAsset *)URLAsset withCompletionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Play a URL, starting at the specified position. Segments and user info can be optionally provided.
 *
 *  For more information, @see `-prepareToPlayURL:atPosition:withSegments:userInfo:completionHandler:`.
 *
 *  @discussion The player immediately reaches the playing state. No segment selection occurs (use methods from the
 *              `SegmentSelection` category if you need to select a segment).
 */
- (void)playURL:(NSURL *)URL
     atPosition:(nullable SRGPosition *)position
   withSegments:(nullable NSArray<id<SRGSegment>> *)segments
       userInfo:(nullable NSDictionary *)userInfo;

/**
 *  Play an asset, starting at the specified position. Segments and user info can be optionally provided.
 *
 *  For more information, @see `-prepareToPlayURLAsset:atPosition:withSegments:userInfo:completionHandler:`.
 *
 *  @discussion The player immediately reaches the playing state. No segment selection occurs (use methods from the
 *              `SegmentSelection` category if you need to select a segment).
 */
- (void)playURLAsset:(AVURLAsset *)URLAsset
          atPosition:(nullable SRGPosition *)position
        withSegments:(nullable NSArray<id<SRGSegment>> *)segments
            userInfo:(nullable NSDictionary *)userInfo;

/**
 *  Play a URL, starting at the default position.
 *
 *  For more information, @see `-playURL:atPosition:withSegments:userInfo:`.
 */
- (void)playURL:(NSURL *)URL;

/**
 *  Play an asset, starting at the default position.
 *
 *  For more information, @see `-playURL:atPosition:withSegments:userInfo:`.
 */
- (void)playURLAsset:(AVURLAsset *)URLAsset;

/**
 *  Ask the player to change its status from pause to play or conversely, depending on the state it is in.
 *
 *  @discussion See `-play`.
 */
- (void)togglePlayPause;

@end

/**
 *  @name Segment selection (notifications resulting from selection will have the `SRGMediaPlayerSelectionKey` set to `YES`)
 */

@interface SRGMediaPlayerController (SegmentSelection)

/**
 *  Prepare to play a URL, starting at a specific position within the segment specified by `index`. User info can be
 *  optionally provided.
 *
 *  @param index    The index of the segment at which playback will start.
 *  @param position The position to start at. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *
 *  For more information, @see `-prepareToPlayURL:atPosition:withSegments:userInfo:completionHandler:`.
 *
 *  @discussion If the segment list is empty or if the index is invalid, playback will start at the default position.
 */
- (void)prepareToPlayURL:(NSURL *)URL
                 atIndex:(NSInteger)index
                position:(nullable SRGPosition *)position
              inSegments:(NSArray<id<SRGSegment>> *)segments
            withUserInfo:(nullable NSDictionary *)userInfo
       completionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Prepare to play an asset, starting at a specific position within the segment specified by `index`. User info can be
 *  optionally provided.
 *
 *  @param index    The index of the segment at which playback will start.
 *  @param position The position to start at. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *
 *  For more information, @see `-prepareToPlayURLAsset:atPosition:withSegments:userInfo:completionHandler:`.
 *
 *  @discussion If the segment list is empty or if the index is invalid, playback will start at the default position.
 */
- (void)prepareToPlayURLAsset:(AVURLAsset *)URLAsset
                      atIndex:(NSInteger)index
                     position:(nullable SRGPosition *)position
                   inSegments:(NSArray<id<SRGSegment>> *)segments
                 withUserInfo:(nullable NSDictionary *)userInfo
            completionHandler:(nullable void (^)(void))completionHandler;

/**
 *  Play a URL, starting at a specific position within the segment specified by `index`. User info can be optionally
 *  provided.
 *
 *  @param index    The index of the segment at which playback will start.
 *  @param position The position to start at. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *
 *  For more information, @see `-playURL:atPosition:withSegments:userInfo:`.
 *
 *  @discussion If the segment list is empty or if the index is invalid, playback will start at the default position.
 */
- (void)playURL:(NSURL *)URL
        atIndex:(NSInteger)index
       position:(nullable SRGPosition *)position
     inSegments:(NSArray<id<SRGSegment>> *)segments
   withUserInfo:(nullable NSDictionary *)userInfo;

/**
 *  Play an asset, starting at a specific position within the segment specified by `index`. User info can be optionally
 *  provided.
 *
 *  @param index    The index of the segment at which playback will start.
 *  @param position The position to start at. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *
 *  For more information, @see `-playURLAsset:atPosition:withSegments:userInfo:`.
 *
 *  @discussion If the segment list is empty or if the index is invalid, playback will start at the default position.
 */
- (void)playURLAsset:(AVURLAsset *)URLAsset
             atIndex:(NSInteger)index
            position:(nullable SRGPosition *)position
          inSegments:(NSArray<id<SRGSegment>> *)segments
        withUserInfo:(nullable NSDictionary *)userInfo;

/**
 *  Seek to a specific time in a segment specified by its index.
 *
 *  @param position The position to seek to. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *  @param index    The index of the segment to seek to.
 *
 *  For more information, @see `-seekToPosition:withCompletionHandler:`.
 *
 *  @discussion If the segment index is invalid, this method does nothing. If the segment is already the one being played,
 *              playback will restart at its beginning. When seeking relative to the current position, add an offset
 *              to `relativeCurrentTime` when building the position to seek to.
 */
- (void)seekToPosition:(nullable SRGPosition *)position
      inSegmentAtIndex:(NSInteger)index
 withCompletionHandler:(nullable void (^)(BOOL finished))completionHandler;

/**
 *  Seek to a specific time in a segment.
 *
 *  @param position The position to seek to. If `nil` or if the specified position lies outside the segment time
 *                  range, playback starts at the default position.
 *  @param segment The segment to seek to.
 *
 *  For more information, @see `-seekToPosition:withCompletionHandler:`.
 *
 *  @discussion If the segment does not belong to the registered segments, this method does nothing. If the segment is
 *              already the one being played, playback will restart at its beginning.
 */
- (void)seekToPosition:(nullable SRGPosition *)position
             inSegment:(id<SRGSegment>)segment
 withCompletionHandler:(nullable void (^)(BOOL finished))completionHandler;

/**
 *  Return the currently selected segment if any, `nil` if none.
 */
@property (nonatomic, readonly, weak, nullable) id<SRGSegment> selectedSegment;

@end

/**
 *  Preview image retrieval.
 */
@interface SRGMediaPlayerController (PreviewImages)

/**
 *  Returns the best preview image available for the specified time, if available.
 */
- (nullable UIImage *)previewImageAtTime:(CMTime)time;

@end

/**
 *  AirPlay. Use player lifecycle blocks (see main `SRGMediaPlayerController` documentation) to setup AirPlay behavior.
 *  Your audio session settings must be compatible with AirPlay, see
 *      https://developer.apple.com/library/content/qa/qa1803/_index.html
 *
 *  Remark: Even if `allowsExternalPlayback` is set to `NO`, sound will still play on an external device if selected, only
 *          the visual tracks of a media won't be played. This is normal expected AirPlay behavior, and this is also how
 *          audio-only medias must be played with AirPlay (so that the screen displays media information notifications,
 *          that the user can control the audio volume from her device, and that the screen does not turn to black).
 *
 *          As a corollary, if you change the `allowsExternalPlayback` from `YES` to `NO` while playing with AirPlay, the
 *          visual tracks will be restored on the device, while the sound will continue over AirPlay. Though weird, this
 *          is expected behavior as well. To restore the sound on the device, the user has to manually open the control
 *          center and choose to route audio through the device again.
 */
@interface SRGMediaPlayerController (AirPlay)

/**
 *  Return `YES` iff the player supports external non-mirrored playback (i.e. moving playback to the external display,
 *  not mirroring the whole device when a video is played).
 */
@property (nonatomic, readonly) BOOL allowsExternalNonMirroredPlayback;

/**
 *  Return `YES` iff non-mirrored external playback is active.
 */
@property (nonatomic, readonly, getter=isExternalNonMirroredPlaybackActive) BOOL externalNonMirroredPlaybackActive;

@end

/**
 *  Background playback behavior.
 */
@interface SRGMediaPlayerController (BackgroundPlayback)

/**
 *  Behavior of the associated view when the application is moved to the background. Use detached behaviors to avoid video
 *  playback being automatically paused.
 *
 *  This setting does not affect picture in picture or AirPlay playbacks, audio playback (allowed in background) or 360°
 *  playback (always paused during the transition).
 *
 *  Default is `SRGMediaPlayerViewBackgroundBehaviorAttached`, i.e. the view remains attached to its controller while in
 *  background, pausing video playback automatically.
 *
 *  @discussion The behavior can be changed at any time but will not affect playback if already performed in background.
 *              It is only applied when the controller view is installed in a view hierarchy.
 */
@property (nonatomic) SRGMediaPlayerViewBackgroundBehavior viewBackgroundBehavior __TVOS_PROHIBITED;

@end

#if TARGET_OS_IOS

/**
 *  Picture in picture functionality (not available on all devices).
 *
 *  Remark: When the application is sent to the background, the behavior is the same as the vanilla picture in picture
 *          controller: If the managed player layer is the one of a view controller's root view ('full screen'), picture
 *          in picture is automatically enabled when switching to the background (provided the corresponding flag has been
 *          enabled in the system settings). This is the only case where switching to picture in picture can be made
 *          automatically. Picture in picture must always be user-triggered, otherwise you application might get rejected
 *          by Apple (@see `AVPictureInPictureController` documentation).
 */
@interface SRGMediaPlayerController (PictureInPicture)

/**
 *  Return the picture in picture controller if picture in picture is available for the device, `nil` otherwise.
 */
@property (nonatomic, readonly, nullable) AVPictureInPictureController *pictureInPictureController;

/**
 *  Optional block which gets called right after picture in picture controller creation.
 */
@property (nonatomic, copy, nullable) void (^pictureInPictureControllerCreationBlock)(AVPictureInPictureController *pictureInPictureController);

@end

#endif

NS_ASSUME_NONNULL_END
