//
//  MagicVideoCellTableViewCell.swift
//  MagicPlayer
//
//  Created by ky on 2019/1/11.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit
import AVFoundation

class MagicVideoCell: UITableViewCell {
  
  @IBOutlet weak var thummnail:UIImageView!
  
  @IBOutlet weak var name:UILabel!
  
  @IBOutlet weak var playback:UIButton!
  
  override func awakeFromNib() {
    
    super.awakeFromNib()
  }
  
  override func setSelected(_ selected: Bool, animated: Bool) {
    
    super.setSelected(selected, animated: animated)
  }
  
  func setVideoInfo(_ url:URL) -> Void {
    
    self.name.text = url.lastPathComponent
    
    DispatchQueue.global().async {
      
      let frameGenerator = FrameGenerator()
      
      let img = frameGenerator.getFrameThumbnail(url, atTime: 0)

      DispatchQueue.main.async {
        
        self.thummnail.image = img
      }
    }
  }
}
