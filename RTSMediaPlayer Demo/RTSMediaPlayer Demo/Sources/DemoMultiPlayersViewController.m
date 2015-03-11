//
//  Created by Frédéric Humbert-Droz on 10/03/15.
//  Copyright (c) 2015 RTS. All rights reserved.
//

#import "DemoMultiPlayersViewController.h"
#import <RTSMediaPlayer/RTSPlayPauseButton.h>

@interface DemoMultiPlayersViewController ()

@property (nonatomic, strong) NSMutableArray *playerViews;
@property (nonatomic, strong) NSMutableArray *mediaPlayerControllers;

@property (nonatomic, assign) NSInteger selectedIndex;

@property (nonatomic, weak) IBOutlet UIView *mainPlayerView;
@property (nonatomic, weak) IBOutlet UIView *playerViewsContainer;

@property (nonatomic, weak) IBOutlet RTSPlayPauseButton *playPauseButton;
@property (nonatomic, weak) IBOutlet UISwitch *thumbnailSwitch;

@property (nonatomic, strong) IBOutletCollection(UIView) NSArray *overlayViews;

@end

@implementation DemoMultiPlayersViewController

#pragma mark - Accessors

- (void) setMediaURLs:(NSArray *)mediaURLs
{
	_mediaURLs = mediaURLs;
	
	self.mediaPlayerControllers = [NSMutableArray array];
	
	for (NSURL *mediaURL in mediaURLs)
	{
		RTSMediaPlayerController *mediaPlayerController = [[RTSMediaPlayerController alloc] initWithContentURL:mediaURL];
		[self.mediaPlayerControllers addObject:mediaPlayerController];
	}
}

#pragma mark - Lifecycle

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaPlayerReadyToPlayNotification:) name:RTSMediaPlayerReadyToPlayNotification object:nil];
	
	[self setSelectedIndex:0];
	
	[self play];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.mediaPlayerControllers makeObjectsPerformSelector:@selector(stop)];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
	{
		NSInteger index = 0;
		for (UIView *playerView in self.playerViewsContainer.subviews)
			playerView.frame = [self rectForPlayerViewAtIndex:index++];
	}
	completion:NULL];
}

#pragma mark - Action

- (void) play
{

	[self.mediaPlayerControllers makeObjectsPerformSelector:@selector(play)];
}

- (void) pause
{
	[self.mediaPlayerControllers makeObjectsPerformSelector:@selector(pause)];
}

- (IBAction) dismiss:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction) thumbnailSwitchDidChange:(UISwitch *)sender
{
	self.playerViewsContainer.hidden = !sender.isOn;

	dispatch_async(dispatch_get_main_queue(), ^{
		SEL action = sender.isOn ? @selector(play) : @selector(stop);
		[self.thumbnailPlayerControllers makeObjectsPerformSelector:action];
	});	
}

#pragma mark - Media Players

- (void) setSelectedIndex:(NSInteger)selectedIndex
{
	_selectedIndex = selectedIndex;
	
	RTSMediaPlayerController *mainMediaPlayerController = self.mediaPlayerControllers[selectedIndex];
	[self setMainMediaPlayerController:mainMediaPlayerController];
	
	[self.playerViewsContainer.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[self.playerViewsContainer layoutIfNeeded];
	
	for (NSInteger index = 0; index<self.mediaPlayerControllers.count; index++)
	{
		if (index == selectedIndex)
			continue;

		CGRect playerViewFrame = [self rectForPlayerViewAtIndex:self.playerViewsContainer.subviews.count];
		UIView *playerView = [[UIView alloc] initWithFrame:playerViewFrame];
		playerView.backgroundColor = [UIColor blackColor];
		playerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
		[self.playerViewsContainer addSubview:playerView];
		
		RTSMediaPlayerController *thumbnailMediaPlayerController = self.mediaPlayerControllers[index];
		[self setThumbnailPlayer:thumbnailMediaPlayerController toView:playerView];
	}
}

- (CGRect) rectForPlayerViewAtIndex:(NSInteger)index
{
	CGFloat playerWidth = MAX(100, MIN(200, CGRectGetWidth(self.playerViewsContainer.frame) / (self.mediaURLs.count-1)));
	CGFloat playerHeight = (playerWidth-10)*10/16;
	
	CGFloat x = self.mediaURLs.count > 2 ? index * playerWidth : (CGRectGetWidth(self.playerViewsContainer.frame)-playerWidth)/2;
	CGFloat y = CGRectGetHeight(self.playerViewsContainer.frame)/2 - playerHeight/2;

	return CGRectMake(x+5, y, playerWidth-10, playerHeight);
}

- (void) setMainMediaPlayerController:(RTSMediaPlayerController *)mediaPlayerController
{
	mediaPlayerController.overlayViews = [NSArray arrayWithArray:self.overlayViews];
	[mediaPlayerController attachPlayerToView:self.mainPlayerView];
	mediaPlayerController.player.muted = NO;
	[mediaPlayerController play];
	
	UITapGestureRecognizer *toggleOverlays = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleOverlays:)];
	[mediaPlayerController setTapGesture:toggleOverlays];
	
	[self.playPauseButton setMediaPlayerController:mediaPlayerController];
}

- (void) setThumbnailPlayer:(RTSMediaPlayerController *)mediaPlayerController toView:(UIView *)playerView
{
	mediaPlayerController.overlayViews = nil;
	[mediaPlayerController attachPlayerToView:playerView];
	mediaPlayerController.player.muted = YES;
	[mediaPlayerController play];

	UITapGestureRecognizer *switchPlayerGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(switchMainPlayer:)];
	[mediaPlayerController setTapGesture:switchPlayerGesture];
}

- (RTSMediaPlayerController *) mediaPlayerControllerForPlayerView:(UIView *)playerView
{
	for (RTSMediaPlayerController *mediaPlayerController in self.mediaPlayerControllers)
	{
		if ([mediaPlayerController.view isEqual:playerView])
			return mediaPlayerController;
	}
	
	return nil;
}

- (NSArray *) thumbnailPlayerControllers
{
	NSMutableArray *thumbnailPlayerControllers = [NSMutableArray array];
	for (RTSMediaPlayerController *mediaPlayerController in self.mediaPlayerControllers)
	{
		if (![mediaPlayerController.view.superview isEqual:self.mainPlayerView])
			[thumbnailPlayerControllers addObject:mediaPlayerController];
	}
	
	return [thumbnailPlayerControllers copy];
}

#pragma mark - Gestures

- (void) toggleOverlays:(UITapGestureRecognizer *)gesture
{
	RTSMediaPlayerController *mediaPlayerController = [self mediaPlayerControllerForPlayerView:gesture.view];
	[mediaPlayerController setOverlaysHidden:![[UIApplication sharedApplication] isStatusBarHidden]];
}

- (void) switchMainPlayer:(UITapGestureRecognizer *)gesture
{
	RTSMediaPlayerController *mediaPlayerController = [self mediaPlayerControllerForPlayerView:gesture.view];
	self.selectedIndex = [self.mediaPlayerControllers indexOfObject:mediaPlayerController];
}

#pragma mark - Notifications

- (void) mediaPlayerReadyToPlayNotification:(NSNotification *)notification
{
	RTSMediaPlayerController *mainMediaPlayerController = self.mediaPlayerControllers[self.selectedIndex];
	
	RTSMediaPlayerController *mediaPlayerController = notification.object;
	mediaPlayerController.player.muted = ![mediaPlayerController.identifier isEqualToString:mainMediaPlayerController.identifier];
}

@end