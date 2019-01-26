//
//  FFmpegPlayer.m
//  MagicPlayer
//
//  Created by ky on 2019/1/22.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import "FFmpegCodec.h"
#import <FFmpeg/ffmpeg.h>
#import "VideoFrame.h"
#import <UIKit/UIKit.h>
#import "MagicPlayer-Swift.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface FFmpegCodec() {
  
  AVFormatContext *_pFormatCtx;
  AVCodecParameters *_pCodecCtxOrig;
  AVCodecContext *_pCodecCtx;
  AVFrame *_pFrame;
  NSInteger _videoStream;
}

@property(nonatomic) NSURL *url;

@end

@implementation FFmpegCodec

- (void)prepare {
  
  const char* szUrl = [self.url.absoluteString cStringUsingEncoding:NSUTF8StringEncoding];
  
  if (avformat_open_input(&_pFormatCtx, szUrl, NULL, NULL) != 0) {
    
    return;
  }
  
  if (avformat_find_stream_info(_pFormatCtx, NULL) < 0) {
    
    return;
  }
  
  AVCodecParameters *pCodecCtxOrig = NULL;
  
  _videoStream = -1;
  
  for (NSInteger i = 0; i < _pFormatCtx->nb_streams; ++i) {
    
    if (_pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      
      pCodecCtxOrig = _pFormatCtx->streams[i]->codecpar;
      
      _videoStream = i;
      
      break;
    }
  }
  
  if (pCodecCtxOrig == NULL) {
    
    return;
  }
  
  AVCodec *pCodec = avcodec_find_decoder(pCodecCtxOrig->codec_id);
  
  if (pCodec == NULL) {
    
    return;
  }
  
  _pCodecCtx = avcodec_alloc_context3(pCodec);
  
  if (_pCodecCtx == NULL) {
    
    return;
  }
  
  if (avcodec_parameters_to_context(_pCodecCtx, pCodecCtxOrig) != 0) {
    
    return;
  }
  
  if (avcodec_open2(_pCodecCtx, pCodec, NULL) < 0) {
    
    return;
  }
  
  _pFrame = av_frame_alloc();
}

- (void)openVideo:(NSURL *)url {
  
  self.url = url;
  
  [self prepare];
  
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
  
  dispatch_async(queue, ^{
    
    [self retriveFrame];
  });
}

- (void)retriveFrame {
  
  NSInteger i = 0;
  
  AVPacket packet;
  
  while (av_read_frame(_pFormatCtx, &packet) >= 0) {
    
    if (packet.stream_index == _videoStream) {
      
      avcodec_send_packet(_pCodecCtx, &packet);
      
      avcodec_receive_frame(_pCodecCtx, _pFrame);
      
      if ((_pCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _pCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        @autoreleasepool {
          
          [self saveVideoFrame:_pFrame width:_pCodecCtx->width height:_pCodecCtx->height frameId:i++];
        }
      }
    }
    
    av_packet_unref(&packet);
  }
  
  av_free(_pFrame);
  
  avcodec_close(_pCodecCtx);
  
  avformat_close_input(&_pFormatCtx);
}

static NSMutableData * copyFrameData(UInt8 *src, int linesize, int width, int height) {
  
  width = MIN(linesize, width);
  
  NSMutableData *md = [NSMutableData dataWithLength: width * height];
  
  Byte *dst = md.mutableBytes;
  
  for (NSUInteger i = 0; i < height; ++i) {
    
    memcpy(dst, src, width);
    
    dst += width;
    
    src += linesize;
  }
  
  return md;
}

- (void)saveVideoFrame:(AVFrame*)pFrame width:(int)width height:(int)height frameId:(NSInteger)frameId {
  
  if (pFrame->data[0] == 0) {
    
    printf("ignore");
    
    return;
  }
  
  VideoFrame *frame = [[VideoFrame alloc] init];
  
  frame.frameId = frameId;
  
  frame.luma = copyFrameData(pFrame->data[0], pFrame->linesize[0], width, height);
  
  frame.chromaB = copyFrameData(pFrame->data[1], pFrame->linesize[1], width >> 1, height >> 1);
  
  frame.chromaR = copyFrameData(pFrame->data[2], pFrame->linesize[2], width >> 1, height >> 1);
  
  frame.width = width;
  
  frame.height = height;

  [[VideoManager shared] addFrame:frame];
}

@end
