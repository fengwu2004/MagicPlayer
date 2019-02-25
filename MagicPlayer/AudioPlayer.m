//
//  AudioPlayer.m
//  MagicPlayer
//
//  Created by ky on 2019/1/26.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import "AudioPlayer.h"
#import "AudioFrame.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#include <pthread.h>

@interface AudioPlayer() {
  
  pthread_mutex_t _mutex;
}

@property (nonatomic, assign) AudioComponentInstance audioUnit;
@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic) UInt32 numBytesPerSample;
@property (nonatomic) UInt32 numOutputChannels;
@property (nonatomic) AudioFrame * currentAudioFrame;
@property (nonatomic) NSUInteger currentAudioFramePos;
@property (nonatomic) BOOL playing;
@property (nonatomic) NSMutableArray *frames;

@end

@implementation AudioPlayer

static AudioPlayer *_instance = nil;

+ (instancetype)shared {
  
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    
    if (!_instance) {
      
      _instance = [[super allocWithZone:NULL] initPrivate];
    }
  });
  
  return _instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
  
  return [self shared];
}

- (id)copyWithZone:(NSZone *)zone {
  
  return self;
}

- (id)init {
  
  return self;
}

- (id)initPrivate {
  
  self = [super init];
  
  pthread_mutex_init(&_mutex, NULL);
  
  _frames = [[NSMutableArray alloc] init];
  
  return self;
}

- (void)updateNextFrame {
  
  pthread_mutex_lock(&_mutex);
  
  if (_frames.count < 1) {
    
    _currentAudioFrame = nil;
  }
  else {
    
    _currentAudioFrame = _frames[0];
    
    [_frames removeObjectAtIndex:0];
  }
  
  _currentAudioFramePos = 0;
  
  pthread_mutex_unlock(&_mutex);
}

- (BOOL)renderFrames:(UInt32)numFrames ioData:(AudioBufferList *)ioData {
  
  for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
    
    memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
  }
  
  if (_currentAudioFrame == nil) {
    
    [self updateNextFrame];
  }
  
  if (!_currentAudioFrame) {
    
    return noErr;
  }
  
  if (_numBytesPerSample == 4) {
    
    memcpy(ioData->mBuffers[0].mData, (uint8_t*)(_currentAudioFrame.leftsamples.bytes) + _currentAudioFramePos * 4, numFrames * 4);
    
    memcpy(ioData->mBuffers[1].mData, (uint8_t*)(_currentAudioFrame.leftsamples.bytes) + _currentAudioFramePos * 4, numFrames * 4);
    
    _currentAudioFramePos += numFrames;
    
    if (_currentAudioFramePos * sizeof(float) == _currentAudioFrame.leftsamples.length) {
      
      _currentAudioFrame = nil;
    }
  }
  
  return noErr;
}

- (void)play {
  
  AudioComponentDescription description = {0};
  
  description.componentType = kAudioUnitType_Output;
  
  description.componentSubType = kAudioUnitSubType_RemoteIO;
  
  description.componentManufacturer = kAudioUnitManufacturer_Apple;
  
  AudioComponent component = AudioComponentFindNext(NULL, &description);
  
  OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
  
  if (status != noErr) {
    
    return;
  }
  
  UInt32 size = sizeof(AudioStreamBasicDescription);
  
  status = AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_outputFormat, &size);
  
  if (status != noErr) {
    
    NSLog(@"无法获取硬件的输出流格式");
    
    return;
  }
  
  _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
  
  _numOutputChannels = _outputFormat.mChannelsPerFrame;
  
  AURenderCallbackStruct callbackStruct;
  
  callbackStruct.inputProc = renderCallback;
  
  callbackStruct.inputProcRefCon = (__bridge void *)(self);
  
  status = AudioUnitSetProperty(_audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));
  
  if (status != noErr) {
    
    NSLog(@"无法设置音频输出单元的回调");
    
    return;
  }
  
  status = AudioUnitInitialize(_audioUnit);
  
  if (status != noErr) {
    
    NSLog(@"无法初始化音频输出单元");
    
    return;
  }
  
  status = AudioOutputUnitStart(_audioUnit);

  if (status == noErr) {

    _playing = YES;
  }
  else {

    _playing = NO;
  }
}

- (void)addFrame:(AVFrame*)pFrame size:(int)data_size {
  
  if (!pFrame || !pFrame->data[0]) {
    
    return;
  }
  
  void *audioData = pFrame->data[0];
  
  NSMutableData *ldata = [NSMutableData dataWithLength:pFrame->nb_samples * 4];
  
  memcpy(ldata.mutableBytes, audioData, pFrame->nb_samples * 4);
  
  NSMutableData *rdata = [NSMutableData dataWithLength:pFrame->nb_samples * 4];
  
  audioData = pFrame->data[1];
  
  memcpy(rdata.mutableBytes, audioData, pFrame->nb_samples * 4);
  
  AudioFrame *frame = [[AudioFrame alloc] init];
  
  frame.leftsamples = ldata;
  
  frame.rightsamples = rdata;
  
  pthread_mutex_lock(&_mutex);
  
  [_frames addObject:frame];
  
  pthread_mutex_unlock(&_mutex);
}

OSStatus renderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList * ioData) {
  
  @autoreleasepool {
  
    AudioPlayer * aam = (__bridge AudioPlayer *)inRefCon;
    
    return [aam renderFrames:inNumberFrames ioData:ioData];
  }
}

@end
