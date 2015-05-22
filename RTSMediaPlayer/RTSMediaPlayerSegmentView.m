//
//  Created by Samuel Défago on 22.05.15.
//  Copyright (c) 2015 RTS. All rights reserved.
//

#import "RTSMediaPlayerSegmentView.h"

#import "RTSMediaPlayerController.h"

@implementation RTSMediaPlayerSegmentView

#pragma mark - Object lifecycle

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Getters and setters

// TODO: Register for periodical segment updates (use RTSPlaybackTimeObserver)

- (void) setMediaPlayerController:(RTSMediaPlayerController *)mediaPlayerController
{
	if (_mediaPlayerController)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:RTSMediaPlayerPlaybackStateDidChangeNotification object:_mediaPlayerController];
	}
	
	_mediaPlayerController = mediaPlayerController;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateDidChange:) name:RTSMediaPlayerPlaybackStateDidChangeNotification object:mediaPlayerController];
}

#pragma mark - Data

- (void) reloadSegments
{
	[self.dataSource mediaPlayerSegmentView:self segmentsForIdentifier:self.mediaPlayerController.identifier completionHandler:^(NSArray *segments, NSError *error) {
		// FIXME: A retry mechanism should be implemented in case of failure
		
		// Sort segments in ascending order
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:YES comparator:^NSComparisonResult(NSValue *timeValue1, NSValue *timeValue2) {
			CMTime time1 = [timeValue1 CMTimeValue];
			CMTime time2 = [timeValue2 CMTimeValue];
			return CMTimeCompare(time1, time2);
		}];
		[self reloadWithSegments:[segments sortedArrayUsingDescriptors:@[sortDescriptor]]];
	}];
}

#pragma mark - RTSMediaPlayerSegmentView protocol

- (void) reloadWithSegments:(NSArray *)segments
{}

#pragma mark - Notifications

- (void) playbackStateDidChange:(NSNotification *)notification
{
	NSAssert([notification.object isKindOfClass:[RTSMediaPlayerController class]], @"Expect a media player controller");
	
	RTSMediaPlayerController *mediaPlayerController = notification.object;
	if (mediaPlayerController.playbackState == RTSMediaPlaybackStateReady)
	{
		[self reloadSegments];
	}
}

@end