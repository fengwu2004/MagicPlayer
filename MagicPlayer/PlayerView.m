//
//  PlayerView.m
//  testOpengles
//
//  Created by ky on 2019/1/24.
//  Copyright © 2019 yellfun. All rights reserved.
//

#import "PlayerView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES3/gl.h>
#import "VideoFrame.h"
#import "MagicPlayer-Swift.h"

@interface PlayerView(){
  
  GLint _uniformSamplers[3];
  GLuint _textures[3];
  GLuint _renderBuffer;
  GLuint _frameBuffer;
  GLint _uniformMatrix;
  GLuint _program;
  GLfloat _vertices[8];
}

@property (nonatomic) CGRect destRect;
@property (nonatomic) CIContext *cicontext;
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CAEAGLLayer *eaglLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) NSThread *playThread;
@property (nonatomic) CGRect rect;
@property (nonatomic) CGFloat scale;

@end

@implementation PlayerView

+ (Class)layerClass {
  
  return [CAEAGLLayer class];
}

- (void)awakeFromNib {
  
  [super awakeFromNib];
}

- (id)initWithFrame:(CGRect)frame {
  
  self = [super initWithFrame:frame];
  
  return self;
}

- (void)setupLayer {
  
  self.eaglLayer = (CAEAGLLayer *)self.layer;

  [self setContentScaleFactor:[[UIScreen mainScreen] scale]];

  self.eaglLayer.opaque = YES;

  self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithBool:NO],kEAGLDrawablePropertyRetainedBacking,
                                       kEAGLColorFormatRGBA8,kEAGLDrawablePropertyColorFormat,
                                       nil];
}

- (void)setupContext {
  
  EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

  if (!context) {
    
    NSLog(@"Failed to initialize OpenGLES 2.0 context");
    
    exit(1);
  }
  
  if (![EAGLContext setCurrentContext:context]) {
    
    NSLog(@"Failed to set current OpenGL context");
    
    exit(1);
  }
  
  self.context = context;
  
  self.cicontext = [CIContext contextWithEAGLContext:self.context];
}

- (void)render {
  
  [EAGLContext setCurrentContext:_context];
  
  VideoFrame *yuvFrame = [VideoManager.shared nextFrame];
  
  [self.cicontext drawImage:yuvFrame.img inRect:_destRect fromRect:CGRectMake(0, 0, yuvFrame.width, yuvFrame.height)];
  
  glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
  
  [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)layoutSubviews {
  
  [super layoutSubviews];
  
  self.destRect = self.bounds;
}

- (void)play {
  
  _scale = UIScreen.mainScreen.scale;
  
  _rect = self.bounds;
  
  [self setupLayer];
  
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
  
  _displayLink.preferredFramesPerSecond = 24;
  
  _playThread = [[NSThread alloc] initWithBlock:^{
    
    [self setupContext];
    
    [self.displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    
    [NSRunLoop.currentRunLoop run];
  }];
  
  [_playThread start];
}

@end
