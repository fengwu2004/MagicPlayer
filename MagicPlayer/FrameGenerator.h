//
//  FrameGenerator.h
//  MagicPlayer
//
//  Created by ky on 2019/2/24.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FrameGenerator : NSObject

- (UIImage*)getFrameThumbnail:(NSURL*)url atTime:(NSInteger)time;

@end

NS_ASSUME_NONNULL_END
