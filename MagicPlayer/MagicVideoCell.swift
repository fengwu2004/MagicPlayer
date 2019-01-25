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
  
  func getVideoThumb(_ url:URL) -> UIImage? {
    
    let asset = AVURLAsset(url: url)
    
    let gen = AVAssetImageGenerator(asset: asset)
    
    gen.appliesPreferredTrackTransform = true
    
    let time = CMTimeMakeWithSeconds(100, preferredTimescale: 600)
    
    if let img = try? gen.copyCGImage(at: time, actualTime: nil) {
      
      let thumb = UIImage(cgImage: img)
      
      return thumb
    }
    
    return nil
  }
  
  func setVideoInfo(_ url:URL) -> Void {
    
    DispatchQueue.global().async {
      
      if let img = self.getVideoThumb(url) {
        
        DispatchQueue.main.async {
        
          self.thummnail.image = img
        }
      }
    }
  }
}
