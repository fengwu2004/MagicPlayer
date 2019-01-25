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

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
  float r_l = right - left;
  float t_b = top - bottom;
  float f_n = far - near;
  float tx = - (right + left) / (right - left);
  float ty = - (top + bottom) / (top - bottom);
  float tz = - (far + near) / (far - near);
  
  mout[0] = 2.0f / r_l;
  mout[1] = 0.0f;
  mout[2] = 0.0f;
  mout[3] = 0.0f;
  
  mout[4] = 0.0f;
  mout[5] = 2.0f / t_b;
  mout[6] = 0.0f;
  mout[7] = 0.0f;
  
  mout[8] = 0.0f;
  mout[9] = 0.0f;
  mout[10] = -2.0f / f_n;
  mout[11] = 0.0f;
  
  mout[12] = tx;
  mout[13] = ty;
  mout[14] = tz;
  mout[15] = 1.0f;
}

@interface PlayerView(){
  
  GLint _uniformSamplers[3];
  GLuint _textures[3];
  GLuint _renderBuffer;
  GLuint _frameBuffer;
  GLint _uniformMatrix;
  GLuint _program;
  GLfloat _vertices[8];
}

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
}

- (void)setupBuffer {
  
  glGenFramebuffers(1, &_frameBuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
  
  glGenRenderbuffers(1, &_renderBuffer);
  glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
  
  [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
}

- (BOOL)setupShaders {
  
  NSString *vertFile = [[NSBundle mainBundle] pathForResource:@"vertexShader" ofType:@"vsh"];
  
  NSString *fragFile = [[NSBundle mainBundle] pathForResource:@"yuvFragment" ofType:@"fsh"];
  
  _program = [self loadShaders:vertFile frag:fragFile];
  
  glLinkProgram(_program);
  
  GLint linkSuccess;
  
  glGetProgramiv(_program, GL_LINK_STATUS, &linkSuccess);
  
  if (linkSuccess == GL_FALSE) {
    
    GLchar messages[256];
    
    glGetProgramInfoLog(_program, sizeof(messages), 0, &messages[0]);
    
    NSString *messageString = [NSString stringWithUTF8String:messages];
    
    NSLog(@"error,%@", messageString);
    
    return NO;
  }
  else {
    
    NSLog(@"link ok");
    
    glBindAttribLocation(_program, 0, "position");
    
    glBindAttribLocation(_program, 1, "texcoord");
    
    _uniformSamplers[0] = glGetUniformLocation(_program, "s_texture_y");
    
    _uniformSamplers[1] = glGetUniformLocation(_program, "s_texture_u");
    
    _uniformSamplers[2] = glGetUniformLocation(_program, "s_texture_v");
    
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    
    return YES;
  }
}

- (void)prepareTexture {
  
  if (0 == _textures[0]) {
    
    glGenTextures(3, _textures);
  }
  
  VideoFrame *yuvFrame = [VideoManager.shared nextFrame];
  
  GLsizei width = (GLsizei)yuvFrame.width;
  
  GLsizei height = (GLsizei)yuvFrame.height;
  
  const UInt8 *pixels[3] = { yuvFrame.luma.bytes, yuvFrame.chromaB.bytes, yuvFrame.chromaR.bytes };
  
  const GLsizei widths[3]  = { width, width / 2, width / 2 };
  
  const GLsizei heights[3] = { height, height / 2, height / 2 };
  
  glBindTexture(GL_TEXTURE_2D, 0);
  
  for (int i = 0; i < 3; ++i) {
    
    glBindTexture(GL_TEXTURE_2D, _textures[i]);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 widths[i],
                 heights[i],
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 pixels[i]);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  }
  
  for (int i = 0; i < 3; ++i) {
    
    glActiveTexture(GL_TEXTURE0 + i);
    
    glBindTexture(GL_TEXTURE_2D, _textures[i]);
    
    glUniform1i(_uniformSamplers[i], i);
  }
}

- (void)render {
  
  [EAGLContext setCurrentContext:_context];
  
  glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
  glViewport(0, 0, _rect.size.width * _scale, _rect.size.height * _scale);
  glClearColor(0, 1, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  glUseProgram(_program);
  
  [self prepareTexture];
  
  static const GLfloat texCoords[] = {
    0.0f, 1.0f,
    1.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 0.0f,
  };
  
  _vertices[0] = -1.0f;
  _vertices[1] = -1.0f;
  
  _vertices[2] =  1.0f;
  _vertices[3] = -1.0f;
  
  _vertices[4] = -1.0f;
  _vertices[5] =  1.0f;
  
  _vertices[6] =  1.0f;
  _vertices[7] =  1.0f;
  
  GLfloat modelviewProj[16] = {
    1,0,0,0,
    0,1,0,0,
    0,0,1,0,
    0,0,0,1
  };
  
  glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
  
  GLuint position = glGetAttribLocation(_program, "position");
  
  glVertexAttribPointer(position, 2, GL_FLOAT, GL_FALSE, 0, _vertices);
  
  GLuint texcoord = glGetAttribLocation(_program, "texcoord");
  
  glEnableVertexAttribArray(0);
  
  glVertexAttribPointer(texcoord, 2, GL_FLOAT, GL_FALSE, 0, texCoords);
  
  glEnableVertexAttribArray(1);
  
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  
  glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
  
  [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)loadShaders:(NSString *)vert frag:(NSString *)frag {
  
  GLuint verShader;
  
  GLuint fragShader;
  
  GLuint program = glCreateProgram();
  
  //编译
  [self complieShader:&verShader type:GL_VERTEX_SHADER file:vert];
  
  [self complieShader:&fragShader type:GL_FRAGMENT_SHADER file:frag];
  
  glAttachShader(program, verShader);
  
  glAttachShader(program, fragShader);
  
  //释放不需要的shader
  glDeleteShader(verShader);
  
  glDeleteShader(fragShader);
  
  return program;
}

- (void)complieShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file {
  
  //读取字符串
  NSString *content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
  
  const GLchar *source = (GLchar *)[content UTF8String];
  
  *shader = glCreateShader(type);
  
  glShaderSource(*shader, 1, &source, NULL);
  
  glCompileShader(*shader);
}

- (void)layoutSubviews {
  
  [super layoutSubviews];
}

- (void)play {
  
  _scale = UIScreen.mainScreen.scale;
  
  _rect = self.bounds;
  
  [self setupLayer];
  
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
  
  _displayLink.preferredFramesPerSecond = 48 * 4;
  
  _playThread = [[NSThread alloc] initWithBlock:^{
    
    [self setupContext];
    
    [self setupBuffer];
    
    [self setupShaders];
  
    [self.displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    
    [NSRunLoop.currentRunLoop run];
  }];
  
  [_playThread start];
}

@end
