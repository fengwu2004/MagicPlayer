//
//  AudioFrame.h
//  MagicPlayer
//
//  Created by ky on 2019/1/27.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioFrame : NSObject

@property (nonatomic) NSData *samples;
@property (nonatomic) CGFloat position;
@property (nonatomic) CGFloat duration;


@end

NS_ASSUME_NONNULL_END
