//
//  PlayerViewController.swift
//  MagicPlayer
//
//  Created by ky on 2019/1/11.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit
import AVKit

class PlayerViewController: UIViewController {
  
  var url:URL?
  
  var playerView:VideoPlayerView!
  
  @IBOutlet weak var preBtn:UIButton!
  
  @IBOutlet weak var nextBtn:UIButton!
  
  @IBOutlet weak var pauseBtn:UIButton!
  
  @IBOutlet weak var playBtn:UIButton!
  
  @IBOutlet weak var playProgress:UISlider!
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    
    playerView = VideoPlayerView(frame: .zero, url: url!)
    
    playerView.translatesAutoresizingMaskIntoConstraints = false
    
    view.insertSubview(playerView, at: 0)
    
    view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[playerView]|", options: [], metrics: nil, views: ["playerView" : playerView]))
    
    view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[playerView]|", options: [], metrics: nil, views: ["playerView" : playerView]))
    
    playProgress.addTarget(self, action: #selector(updatePlaybackPos(_:)), for: UIControl.Event.valueChanged)
  }
  
  override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    
    return .landscapeRight
  }
  
  override func viewDidAppear(_ animated: Bool) {
    
    super.viewDidAppear(animated)
    
    playerView.play()
  }
  
  @objc
  func updatePlaybackPos(_ sender:UISlider) -> Void {
    
    
  }
}
