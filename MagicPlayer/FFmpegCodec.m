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
  
  AVCodecContext *pCodecCtx;
}

@end

@implementation FFmpegCodec

- (void)openVideo:(NSURL *)url {
  
  const char* szUrl = [url.absoluteString cStringUsingEncoding:NSUTF8StringEncoding];
  
  AVFormatContext *pFormatCtx = NULL;
  
  if (avformat_open_input(&pFormatCtx, szUrl, NULL, NULL) != 0) {
    
    return;
  }
  
  if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
    
    return;
  }
  
//  av_dump_format(pFormatCtx, 0, szUrl, 0);
  
  AVCodecContext *pCodecCtxOrig = NULL;
  
  NSInteger videoStream = -1;
  
  for (NSInteger i = 0; i < pFormatCtx->nb_streams; ++i) {
    
    if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      
      pCodecCtxOrig = pFormatCtx->streams[i]->codec;
      
      videoStream = i;
      
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
  
  pCodecCtx = avcodec_alloc_context3(pCodec);
  
  if (pCodecCtx == NULL) {
    
    return;
  }
  
  if (avcodec_copy_context(pCodecCtx, pCodecCtxOrig) != 0) {
    
    return;
  }
  
  if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
    
    return;
  }
  
  NSLog(@"xx");
  
  AVFrame *pFrame = av_frame_alloc();
  
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
  
  dispatch_async(queue, ^{
    
    NSInteger i = 0;
    
    AVPacket packet;
    
    int frameFinished = 0;
    
    while (av_read_frame(pFormatCtx, &packet) >= 0) {
      
      if (packet.stream_index == videoStream) {
        
        avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
        
        if (frameFinished && (pCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || pCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
          
          @autoreleasepool {
            
            [self saveFrame:pFrame width:pCodecCtx->width height:pCodecCtx->height frameId:i++];
          }
        }
      }
      
      av_packet_unref(&packet);
      
      av_frame_unref(pFrame);
    }
    
    av_free(pFrame);
    
    avcodec_close(pCodecCtx);
    
    avcodec_close(pCodecCtxOrig);
    
    avformat_close_input(&pFormatCtx);
  });
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

- (void)saveFrame:(AVFrame*)pFrame width:(int)width height:(int)height frameId:(NSInteger)frameId {
  
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
