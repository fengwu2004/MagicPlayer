//
//  TouchEnableOfClipView.swift
//  MagicPlayer
//
//  Created by ky on 2019/3/3.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit

class TouchEnableOfClipView: UIView {

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    
    if self.alpha <= 0.01 || !self.isUserInteractionEnabled || self.isHidden {
      
      return nil
    }
    
    if !self.point(inside: point, with: event) && self.clipsToBounds {
      
      return nil
    }
    
    for subview in self.subviews.reversed() {
      
      let subviewPoint = subview.convert(point, from: self)
      
      if let hitView = subview.hitTest(subviewPoint, with: event) {
        
        return hitView
      }
    }
    
    return nil
  }
}
