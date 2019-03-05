//
//  VideoPlayerView.swift
//  MagicPlayer
//
//  Created by ky on 2019/1/13.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit
import AVKit

class VideoPlayerView: UIView {
  
  var renderView:PlayerView!
  
  var audioPlayer:AudioPlayer!
  
  var deocodec = FFmpegCodec()
  
  var url:URL!
  
  init(frame:CGRect, url:URL) {
    
    super.init(frame: frame)
    
    self.url = url
    
    renderView = PlayerView(frame: .zero)
    
    self.addSubview(renderView)
  }
  
  override func layoutSubviews() {
    
    super.layoutSubviews()
    
    renderView.center = self.center
    
    renderView.frame = self.frame
  }
  
  func play(_ loadSuccessBlock:@escaping (Float)->Void, updateProgress:@escaping (Int)->Void) -> Void {
    
    renderView.play()
    
    AudioPlayer.shared.play()
    
    DispatchQueue.global().async {
      
      self.deocodec.openVideo(self.url, loadSuccess: {(time:Float) in
        
        loadSuccessBlock(time)
        
      }, onFrame: {(frameIndex:Int) in
        
        updateProgress(frameIndex)
      })
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    
    super.init(coder: aDecoder)
  }
}
