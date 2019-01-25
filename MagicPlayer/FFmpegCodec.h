//
//  FFmpegPlayer.h
//  MagicPlayer
//
//  Created by ky on 2019/1/22.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFmpegCodec : NSObject

- (void)openVideo:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END
