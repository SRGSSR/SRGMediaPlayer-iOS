//
//  Copyright (c) SRG. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "NSBundle+SRGMediaPlayer.h"

#import "SRGMediaPlayerController.h"

@implementation NSBundle (SRGMediaPlayer)

+ (instancetype)srg_mediaPlayerBundle
{
    static NSBundle *bundle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bundle = [NSBundle bundleForClass:[SRGMediaPlayerController class]];
    });
    return bundle;
}

@end