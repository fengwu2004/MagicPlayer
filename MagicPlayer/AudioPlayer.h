//
//  AudioPlayer.h
//  MagicPlayer
//
//  Created by ky on 2019/1/26.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FFmpeg/frame.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioPlayer : NSObject

@property (class, readonly, strong) AudioPlayer *shared;

- (void)play;

- (void)addFrame:(AVFrame*)pFrame size:(int)data_size;

@end

NS_ASSUME_NONNULL_END
