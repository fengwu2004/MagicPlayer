//
//  AudioPlayer.m
//  MagicPlayer
//
//  Created by ky on 2019/1/26.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import "AudioPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>

typedef void(^AieAudioManagerOutputBlock)(float * data, UInt32 numFrames, UInt32 numChannels);

@interface AudioPlayer() {
  
  float *_outData;
}

@property (nonatomic, assign) AudioComponentInstance audioUnit;
@property (nonatomic, assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic) UInt32 numBytesPerSample;
@property (nonatomic) UInt32 numOutputChannels;
@property (nonatomic) NSMutableData * currentAudioFrame;
@property (nonatomic) NSUInteger currentAudioFramePos;
@property (nonatomic) BOOL playing;
@property (nonatomic, strong) AieAudioManagerOutputBlock outputBlock;

@end

@implementation AudioPlayer

- (BOOL)renderFrames:(UInt32)numFrames ioData:(AudioBufferList *)ioData {
  
  for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++) {
    
    memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
  }
  
  if (_playing && _outputBlock) {
    
    _outputBlock(_outData, numFrames, _numOutputChannels);
    
    if (_numBytesPerSample == 2) {
      
      float scale = (float)INT16_MAX;
      
      vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames * _numOutputChannels);
      
      for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        
        int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
        
        for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
          
          vDSP_vfix16(_outData + iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
        }
      }
    }
  }
  
  return noErr;
}

- (void)audioCallbackFillData:(float *)outData numFrames:(UInt32)numFrames numChannels:(UInt32)numChannels {
  
  const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
  
  const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
  
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

OSStatus renderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList * ioData) {
  
  AudioPlayer * aam = (__bridge AudioPlayer *)inRefCon;
  
  return [aam renderFrames:inNumberFrames ioData:ioData];
}

@end
