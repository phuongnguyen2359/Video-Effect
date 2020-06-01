//
//  SavedViewController.swift
//  VideoEffect
//
//  Created by TT on 5/25/20.
//  Copyright © 2020 NTP. All rights reserved.
//

import UIKit
import AVKit

class SavedViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    var fileNames = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        readFilesFromDirectory()
    }
    
    func readFilesFromDirectory() {
        do {
            fileNames = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory())
            tableView.reloadData()
        } catch {
            
        }
    }
    
    private func playVideo(at path: URL) {

        let playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: path)
        playerViewController.player = player
        present(playerViewController, animated: true) {
            player.play()
        }
    }

}

extension SavedViewController: UITableViewDataSource, UITableViewDelegate {
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SavedVideoTableViewCell", for: indexPath) as! SavedVideoTableViewCell
        cell.setUI(name: fileNames[indexPath.row], path: getVideoPath(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var path = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        path.appendPathComponent(fileNames[indexPath.row])
        playVideo(at: path)
    }
    
    func getVideoPath(indexPath: IndexPath) -> URL {
        var path = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        path.appendPathComponent(fileNames[indexPath.row])
        return path
    }
}

class SavedVideoTableViewCell: UITableViewCell {
    
    @IBOutlet weak var videoName: UILabel!
    @IBOutlet weak var thumb: UIImageView!
    
    var videoPath: URL?
        
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    func setUI(name: String, path: URL) {
        self.videoName.text = name
    }
}
