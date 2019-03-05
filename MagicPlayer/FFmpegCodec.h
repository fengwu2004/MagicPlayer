//
//  FFmpegPlayer.h
//  MagicPlayer
//
//  Created by ky on 2019/1/22.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^LoadSucces)(float time);
typedef void(^UpdateFrame)(NSInteger frame);

@interface FFmpegCodec : NSObject

- (void)openVideo:(NSURL*)url loadSuccess:(LoadSucces)locdSuccess onFrame:(UpdateFrame)everyFrame;

@end

NS_ASSUME_NONNULL_END
