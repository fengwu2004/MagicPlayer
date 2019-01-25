//
//  VideoManager.swift
//  MagicPlayer
//
//  Created by ky on 2019/1/24.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit

final class VideoManager: NSObject {
  
  @objc static var shared = VideoManager()
  
  private override init() {
    
    super.init()
  }
  
  var frames = [VideoFrame]()
  
  var condition = NSCondition()

  @objc func addFrame(_ frame:VideoFrame) -> Void {
    
    condition.lock()
    
    frames.append(frame)
    
    if frames.count >= 24 {
      
      condition.wait()
    }
    
    condition.unlock()
    
    condition.signal()
  }
  
  @objc func nextFrame() -> VideoFrame? {
    
    condition.lock()
    
    if frames.isEmpty {
      
      condition.wait()
    }

    let frame = frames.removeFirst()
    
    condition.unlock()
    
    condition.signal()
    
    return frame
  }
}
