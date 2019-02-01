//
//  VideoFrame.h
//  MagicPlayer
//
//  Created by ky on 2019/1/24.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoFrame : NSObject

@property(nonatomic) NSInteger frameId;
@property(nonatomic) NSMutableData *luma;
@property(nonatomic) NSMutableData *chromaB;
@property(nonatomic) NSMutableData *chromaR;
@property(nonatomic) NSInteger width;
@property(nonatomic) NSInteger height;
@property(nonatomic) CIImage *img;

@end

NS_ASSUME_NONNULL_END
