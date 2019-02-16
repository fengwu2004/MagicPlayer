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
#import "AudioFrame.h"
#import "AudioPlayer.h"
#import <UIKit/UIKit.h>
#import "MagicPlayer-Swift.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface FFmpegCodec() {
  
  AVFormatContext *_pFormatCtx;
  AVCodecContext *_pVideoCodecCtx;
  AVCodecContext *_pAudioCodecCtx;
  AVFrame *_pVideoFrame;
  AVFrame *_pAudioFrame;
  NSInteger _videoStream;
  NSInteger _audioStream;
  CGFloat _audioTimeBase;
}

@property(nonatomic) NSURL *url;

@end

@implementation FFmpegCodec

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase) {
  
  CGFloat fps, timebase;
  
  if (st->time_base.den && st->time_base.num) {
    
    timebase = av_q2d(st->time_base);
  }
  else if(st->codec->time_base.den && st->codec->time_base.num) {
    
    timebase = av_q2d(st->codec->time_base);
  }
  else {
    
    timebase = defaultTimeBase;
  }
  
  if (st->avg_frame_rate.den && st->avg_frame_rate.num) {
    
    fps = av_q2d(st->avg_frame_rate);
  }
  else if (st->r_frame_rate.den && st->r_frame_rate.num) {
    
    fps = av_q2d(st->r_frame_rate);
  }
  else {
    
    fps = 1.0 / timebase;
  }
  
  if (pFPS) {
    
    *pFPS = fps;
  }
  
  if (pTimeBase) {
    
    *pTimeBase = timebase;
  }
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
  
  AVCodecParameters *pAudioCodecParam = NULL;
  
  _videoStream = -1;
  
  _audioStream = -1;
  
  for (NSInteger i = 0; i < _pFormatCtx->nb_streams; ++i) {
    
    //video
    if (_videoStream == -1 && _pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      
      pVideoCodecParam = _pFormatCtx->streams[i]->codecpar;
      
      _videoStream = i;
    }
    
    //audio
    if (_audioStream == -1 && _pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
      
      pAudioCodecParam = _pFormatCtx->streams[i]->codecpar;
      
      _audioStream = i;
    }
  }
  
  if (pVideoCodecParam == NULL) {
    
    NSLog(@"视频解码失败");
    
    return;
  }
  
  if (pAudioCodecParam == NULL) {
    
    NSLog(@"音频解码失败");
    
    return;
  }
  
  AVCodec *pVideoCodec = avcodec_find_decoder(pVideoCodecParam->codec_id);
  
  if (pVideoCodec == NULL) {
    
    return;
  }
  
  //video
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
  
  //audio
  AVCodec *pAudioCodec = avcodec_find_decoder(pAudioCodecParam->codec_id);
  
  if (!pAudioCodec) {
    
    return;
  }
  
  _pAudioCodecCtx = avcodec_alloc_context3(pAudioCodec);
  
  if (avcodec_parameters_to_context(_pAudioCodecCtx, pAudioCodecParam) != 0) {
    
    return;
  }
  
  if (avcodec_open2(_pAudioCodecCtx, pAudioCodec, NULL) < 0) {
    
    return;
  }
  
  _pAudioFrame = av_frame_alloc();
  
  AVStream *st = _pFormatCtx->streams[_audioStream];
  
  avStreamFPSTimeBase(st, 0.025, 0, &_audioTimeBase);
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
      
      avcodec_send_packet(_pVideoCodecCtx, &packet);
      
      avcodec_receive_frame(_pVideoCodecCtx, _pVideoFrame);
      
      if ((_pVideoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _pVideoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        @autoreleasepool {
          
          [self saveVideoFrame:_pVideoFrame width:_pVideoCodecCtx->width height:_pVideoCodecCtx->height frameId:i++];
        }
      }
    }
    
    if (packet.stream_index == _audioStream) {
      
      avcodec_send_packet(_pAudioCodecCtx, &packet);
      
      avcodec_receive_frame(_pAudioCodecCtx, _pAudioFrame);
      
      @autoreleasepool {
        
        [self saveAudioFrame:_pAudioFrame];
      }
    }
    
    av_packet_unref(&packet);
  }
  
  av_free(_pVideoFrame);
  
  av_free(_pAudioFrame);
  
  avcodec_close(_pVideoCodecCtx);
  
  avcodec_close(_pAudioCodecCtx);
  
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

- (void)saveAudioFrame:(AVFrame*)pFrame {
  
  if (pFrame->data[0] == 0) {
    
    printf("ignore");
    
    return;
  }
  
//  printf("%d %d %d \n", pFrame->format, (int)pFrame->channel_layout, pFrame->channels);
  
  int data_size = av_samples_get_buffer_size(NULL, _pAudioCodecCtx->channels, pFrame->nb_samples, _pAudioCodecCtx->sample_fmt, 1);
  
  [[AudioPlayer shared] addFrame:pFrame size:data_size];
}

@end
