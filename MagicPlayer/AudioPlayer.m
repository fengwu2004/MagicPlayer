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

typedef void(^AudioManagerOutputBlock)(float * data, UInt32 numFrames, UInt32 numChannels);

@interface AudioPlayer() {
  
  float *_outData;
  pthread_mutex_t _mutex;
}

@property (nonatomic, assign) AudioComponentInstance audioUnit;
@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic) UInt32 numBytesPerSample;
@property (nonatomic) UInt32 numOutputChannels;
@property (nonatomic) AudioFrame * currentAudioFrame;
@property (nonatomic) NSUInteger currentAudioFramePos;
@property (nonatomic) BOOL playing;
@property (nonatomic, strong) AudioManagerOutputBlock outputBlock;
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
  
  _outData = (float *)calloc(4096 * 2, sizeof(float));
  
  _frames = [[NSMutableArray alloc] init];
  
  return self;
}

- (BOOL)renderFrames:(UInt32)numFrames ioData:(AudioBufferList *)ioData {
  
  for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
    
    memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
  }
  
  if (_playing && _outputBlock) {
    
    _outputBlock(_outData, numFrames, _numOutputChannels);
    
    if (_numBytesPerSample == 4) {
      
      float zero = 0.0;
      
      for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        
        int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
        
        for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
          
          vDSP_vsadd(_outData + iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
        }
      }
    }
  }
  
  return noErr;
}

- (void)audioCallbackFillData:(float *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels {
  
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
  
  if (!_currentAudioFrame) {
    
    return;
  }
  
  const void *bytes = (Byte *)_currentAudioFrame.samples.bytes + _currentAudioFramePos;
  
  const NSUInteger bytesLeft = (_currentAudioFrame.samples.length - _currentAudioFramePos);
  
  const NSUInteger frameSizeOf = numChannels * sizeof(float);
  
  const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
  
  const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
  
  memcpy(outData, bytes, bytesToCopy);
  
  numFrames -= framesToCopy;

  outData += framesToCopy * numChannels;
}

- (void)play {
  
  __weak AudioPlayer *weakself = self;
  
  self.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels){
    
    __strong AudioPlayer *stongself = weakself;
    
    [stongself audioCallbackFillData:outData numFrames:numFrames numChannels:numChannels];
  };
  
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

- (void)addFrame:(AVFrame*)pFrame audioTimeBase:(CGFloat)audioTimeBase {
  
  if (!pFrame || !pFrame->data[0]) {
    
    return;
  }
  
  void *audioData = pFrame->data[0];
  
  NSInteger numFrames = pFrame->nb_samples;
  
  const NSUInteger numElements = numFrames * _numOutputChannels;
  
  NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
  
  float scale = 1.0 / (float)INT16_MAX;
  
  vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
  
  vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
  
  AudioFrame *frame = [[AudioFrame alloc] init];
  
  frame.position = av_frame_get_best_effort_timestamp(pFrame) * audioTimeBase;
  
  frame.duration = av_frame_get_pkt_duration(pFrame) * audioTimeBase;
  
  frame.samples = data;
  
  pthread_mutex_lock(&_mutex);
  
  [_frames addObject:frame];
  
  pthread_mutex_unlock(&_mutex);
}

OSStatus renderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList * ioData) {
  
  AudioPlayer * aam = (__bridge AudioPlayer *)inRefCon;
  
  return [aam renderFrames:inNumberFrames ioData:ioData];
}

@end
