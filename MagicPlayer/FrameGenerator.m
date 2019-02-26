//
//  FrameGenerator.m
//  MagicPlayer
//
//  Created by ky on 2019/2/24.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import "FrameGenerator.h"
#import <FFmpeg/ffmpeg.h>
#import <CoreImage/CoreImage.h>

static CIContext *cicontext = nil;

@interface FrameGenerator(){
  
  AVFormatContext *_pFormatCtx;
  AVCodecContext *_pVideoCodecCtx;
  AVFrame *_pVideoFrame;
  int _videoStream;
}

@property (nonatomic) NSURL *url;

@end

@implementation FrameGenerator

+ (CIContext*)context {
  
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    
    cicontext = [CIContext contextWithEAGLContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3]];
  });
  
  return cicontext;
}

- (void)prepare {
  
  const char* szUrl = [self.url.absoluteString cStringUsingEncoding:NSUTF8StringEncoding];
  
  if (avformat_open_input(&_pFormatCtx, szUrl, NULL, NULL) != 0) {
    
    return;
  }
  
  if (avformat_find_stream_info(_pFormatCtx, NULL) < 0) {
    
    return;
  }
  
  AVCodecParameters *pVideoCodecParam = NULL;
  
  AVCodec *pVideoCodec = NULL;
  
  _videoStream = av_find_best_stream(_pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pVideoCodec, 0);
  
  _pVideoCodecCtx = avcodec_alloc_context3(pVideoCodec);
  
  if (_pVideoCodecCtx == NULL) {
    
    return;
  }
  
  if (avcodec_parameters_to_context(_pVideoCodecCtx, pVideoCodecParam) != 0) {
    
    return;
  }
  
  if (avcodec_open2(_pVideoCodecCtx, pVideoCodec, NULL) < 0) {
    
    return;
  }
  
  _pVideoFrame = av_frame_alloc();
}

- (CGImageRef)getFrameThumbnail:(NSURL*)url atTime:(NSInteger)time {
  
  [self prepare];
  
  AVPacket packet;
  
  while (av_read_frame(_pFormatCtx, &packet) >= 0) {
    
    if (packet.stream_index == _videoStream) {
      
      avcodec_send_packet(_pVideoCodecCtx, &packet);
      
      avcodec_receive_frame(_pVideoCodecCtx, _pVideoFrame);
      
      if ((_pVideoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _pVideoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        @autoreleasepool {
          
          [self saveVideoFrame:_pVideoFrame width:_pVideoCodecCtx->width height:_pVideoCodecCtx->height];
        }
      }
      
      break;
    }
    
    av_packet_unref(&packet);
  }
  
  av_packet_unref(&packet);
  
  av_free(_pVideoFrame);
  
  return nil;
}

- (void)saveVideoFrame:(AVFrame*)pFrame width:(int)width height:(int)height {
  
  CVPixelBufferRef pixelBuffer = NULL;
  
  CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  
  CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  
  CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);
  
  CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &pixelBuffer);
  
  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  
  uint8_t *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
  
  memcpy(yDestPlane, pFrame->data[0], width * height);
  
  uint8_t *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
  
  NSInteger numberOfElementsForChroma = (width >> 1) * (height >> 1);
  
  for (int i = 0, j = 0; i < numberOfElementsForChroma * 2; ++j) {
    
    uvDestPlane[i] = (pFrame->data[1])[j];
    
    uvDestPlane[i + 1] = (pFrame->data[2])[j];
    
    i += 2;
  }
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  
  CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
  
  CIContext *context = [[self class] context];
  
  CGImageRef cgimage = [context createCGImage:ciimage fromRect:ciimage.extent];
  
  
}

@end
