//
//  ViewController.swift
//  MagicPlayer
//
//  Created by ky on 2019/1/11.
//  Copyright © 2019 yellfun. All rights reserved.
//

import UIKit
import AVKit

class MediaListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  
  @IBOutlet weak var videoTable:UITableView!
  
  private var videoUrls:[URL]?
  
  private let cellIdentifier = "VideoCell"
  
  func loadData() -> Void {
    
    if let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
      
      videoUrls = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [])
    }
  }
  
  func setupVideoTable() -> Void {
    
    videoTable.sectionHeaderHeight = 0.01
    
    videoTable.sectionFooterHeight = 0.01
    
    videoTable.register(UINib(nibName: "MagicVideoCell", bundle: nil), forCellReuseIdentifier: cellIdentifier)
  }
  
  override func viewDidLoad() {
    
    super.viewDidLoad()
    
    setupVideoTable()
    
    loadData()
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
    if let videoUrls = videoUrls {
      
      return videoUrls.count
    }
    
    return 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
    let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! MagicVideoCell
    
    cell.setVideoInfo(videoUrls![indexPath.row])
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    
    return 0.01
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    
    return 0.01
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    
    return 100
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    
    tableView.deselectRow(at: indexPath, animated: true)
    
    let vc = PlayerViewController()
    
    vc.url = videoUrls![indexPath.row]
    
    self.present(vc, animated: true)
  }
}

