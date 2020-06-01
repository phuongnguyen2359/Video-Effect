//
//  MainViewController.swift
//  VideoEffect
//
//  Created by TT on 5/22/20.
//  Copyright © 2020 NTP. All rights reserved.
//

import UIKit
import AVKit
import MobileCoreServices
import Photos

class MainViewController: UIViewController {
    
    @IBOutlet weak var metalView: MetalView!
    @IBOutlet weak var firstThumb: UIImageView!
    @IBOutlet weak var secondThumb: UIImageView!
    @IBOutlet weak var firstDuration: UILabel!
    @IBOutlet weak var secondDurationLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var savingLabel: UILabel!
    
    var didSelectVideo: ((URL) -> Void)?
    
    var firstVideoUrl: URL?
    var secondVideoUrl: URL?
    let firstPlayer: AVPlayer = AVPlayer()
    let secondPlayer: AVPlayer = AVPlayer()
    var firstPlayerItem: AVPlayerItem!
    var secondPlayerItem: AVPlayerItem!
    
    var firstVidAssetReader: AVAssetReader!
    var secondVidAssetReader: AVAssetReader!
    var firstVidAssetOutput: AVAssetReaderTrackOutput!
    var secondVidAssetOutput: AVAssetReaderTrackOutput!
    var textureCache: CVMetalTextureCache?
    
    
    var overlapDuration: Float = minOverlapDuration
    var blurSizeConst = 20

    
    var blurWeights = [BlurWeight]()
    
    //A smarter and faster solution is the CADisplayLink class, which automatically calls a method you define as soon as a screen redraw happens, so you always have maximum time to execute your update code.
    lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .current, forMode: .default)
        displayLink.isPaused = true
        displayLink.preferredFramesPerSecond = 60
        return displayLink
    }()
    
    
    lazy var firstPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    lazy var secondPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard blurWeights.isEmpty else { return }
        setupBlurWeights()
        metalView.blurWeights = blurWeights
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        displayLink.invalidate()
    }
    
    @objc private func readBuffer(_ sender: CADisplayLink) {
        var firstVideoTime = CMTime.invalid
        var secondVideoTime = CMTime.invalid
        
        let nextVSync = sender.timestamp + sender.duration
        
        firstVideoTime = firstPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
        
        secondVideoTime = secondPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
        
        var firstPixelBuffer: CVPixelBuffer?
        var secondPixelBuffer: CVPixelBuffer?
        
        let firstThreshHold =  firstPlayerItem.duration.seconds * 0.97
        let shouldPlaySecondVideo = (firstPlayer.currentTime().seconds > firstThreshHold)

        if  shouldPlaySecondVideo {
            secondPlayer.play()
        }

//        if secondPlayer.rate == 0 && ((firstPlayerItem.duration.seconds - firstVideoTime.seconds) <= Double(self.overlapDuration)) {
//            secondPlayer.play()
//        }
        
        if firstPlayer.rate != 0 {
            if firstPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: firstVideoTime) {
                firstPixelBuffer = firstPlayerItemVideoOutput.copyPixelBuffer(forItemTime: firstVideoTime, itemTimeForDisplay: nil)
                self.metalView.firstPixelBuffer = firstPixelBuffer
            }
            
            self.metalView.firstVidRemainTime = firstPlayerItem.duration.seconds - firstVideoTime.seconds
            
            let firstThreshHold =  firstPlayerItem.duration.seconds * 0.8
            let shouldApplyBlur = (firstPlayer.currentTime().seconds > firstThreshHold)
            if shouldApplyBlur {
                self.metalView.blurSizeConst = self.blurSizeConst
            }
            self.metalView.shouldApplyBlur = shouldApplyBlur
            
        } else {
            self.metalView.firstPixelBuffer = nil
            self.metalView.firstVidRemainTime = 0
        }
        
        if secondPlayer.rate != 0 {
            if secondPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: secondVideoTime) {
                secondPixelBuffer = secondPlayerItemVideoOutput.copyPixelBuffer(forItemTime: secondVideoTime, itemTimeForDisplay: nil)
                self.metalView.secondPixelBuffer = secondPixelBuffer
            }
                        
            self.metalView.secondVidRemainTime = secondPlayerItem.duration.seconds - secondVideoTime.seconds
            
            let secondThreshHold = secondPlayerItem.duration.seconds * 0.1
            let shouldApplyBlur = (secondPlayerItem.currentTime().seconds < secondThreshHold)
            self.metalView.shouldApplyBlur = shouldApplyBlur

        } else {
            self.metalView.secondPixelBuffer = nil
            self.metalView.secondVidRemainTime = 0
        }
        
        if firstPixelBuffer != nil || secondPixelBuffer != nil {
            self.metalView.setNeedsDisplay()
        }
    }
    
    @IBAction func filterEffectButtonDidTap(_ sender: Any) {
    }
    
    
    @IBAction func saveButtonDidTap(_ sender: Any) {
        guard let firstUrl = self.firstVideoUrl, let secondUrl = self.secondVideoUrl else {
            return
        }
        let contentMode = SupportedContentMode.createFromUIViewContentMode(metalView.contentMode) ?? SupportedContentMode.scaleAspectFit
        self.metalView.prepareForSaveVideo()
        self.metalView.videoMaker?.startSession()
        self.loadingIndicator.isHidden = false
        self.savingLabel.isHidden = false
        
        DispatchQueue.global().async {
            do {
                try self.prepareRecording()
                
                self.firstVidAssetReader.startReading()
                self.secondVidAssetReader.startReading()
                
                var isStartReadingSecondVid = false
                var firstVidToEnd = false
                var secondVidToEnd = false
                var firstTexture: MTLTexture? = nil
                var secondTexture: MTLTexture? = nil
                
                let firstDuration = AVAsset(url: firstUrl).duration
                let secondDuration = AVAsset(url: secondUrl).duration
                
                while !firstVidToEnd || !secondVidToEnd {
                    autoreleasepool {
                        if let firstSample = self.firstVidAssetOutput.copyNextSampleBuffer() {
                            
                            let currentTimeStamp = firstSample.presentationTimeStamp
                            if (firstDuration.seconds - currentTimeStamp.seconds) <= Double(self.overlapDuration) {
                                isStartReadingSecondVid = true
                            }
                            if let firstFrame = self.getTexture(from: firstSample) {
                                self.metalView.firstVidRemainTime = firstDuration.seconds - currentTimeStamp.seconds
                                firstTexture = firstFrame
                            }
                        } else {
                            firstTexture = nil
                            firstVidToEnd = true
                        }
                        
                        if isStartReadingSecondVid {
                            if let secondSample = self.secondVidAssetOutput.copyNextSampleBuffer() {
                                let currentTimeStamp = secondSample.presentationTimeStamp
                                if let secondFrame = self.getTexture(from: secondSample) {
                                    self.metalView.secondVidRemainTime = secondDuration.seconds - currentTimeStamp.seconds
                                    secondTexture = secondFrame
                                }
                            } else {
                                secondTexture = nil
                                secondVidToEnd = true
                            }
                        }
                        
                        self.metalView.writeFrame(firstVideoTexture: firstTexture, secondVideoTexture: secondTexture, supportedContentMode: contentMode)
                    }
                }
                self.metalView.videoMaker?.finishSession()
                self.metalView.videoMaker = nil
                self.firstVidAssetReader.cancelReading()
                self.secondVidAssetReader.cancelReading()
                
                DispatchQueue.main.async {
                    self.loadingIndicator.isHidden = true
                    self.savingLabel.text = "Saving Successfully..."
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    self.savingLabel.isHidden = true
                    self.saveToAlbum()
                })
                
            } catch {
                DispatchQueue.main.async {
                    print("Saving unsuccessfully")
                }
            }
            
        }
        
    }
    
    func saveToAlbum() {
    }
    
    private func prepareRecording() throws {
        guard let firstURL = firstVideoUrl, let secondURL = secondVideoUrl else { return }
        let firstAsset = AVAsset(url: firstURL)
        firstVidAssetReader = try AVAssetReader(asset: firstAsset)
        
        let secondAsset = AVAsset(url: secondURL)
        secondVidAssetReader = try AVAssetReader(asset: secondAsset)
        
        let videoReaderSetting: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        firstVidAssetOutput = AVAssetReaderTrackOutput(track: firstAsset.tracks(withMediaType: .video).first!, outputSettings: videoReaderSetting)
        if firstVidAssetReader.canAdd(firstVidAssetOutput) {
            firstVidAssetReader.add(firstVidAssetOutput)
        } else {
            fatalError()
        }
        
        secondVidAssetOutput = AVAssetReaderTrackOutput(track: secondAsset.tracks(withMediaType: .video).first!,
                                                        outputSettings: videoReaderSetting)
        if secondVidAssetReader.canAdd(secondVidAssetOutput) {
            secondVidAssetReader.add(secondVidAssetOutput)
        } else { fatalError() }
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Renderer.sharedInstance.device, nil, &textureCache)
    }
    
    private func getTexture(from sampleBuffer: CMSampleBuffer) -> MTLTexture? {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)

            var texture: CVMetalTexture?
            
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, imageBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, 0, &texture)
          
            if let texture = texture {
                return CVMetalTextureGetTexture(texture)
            }
        }
        return nil
    }
    
        
    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
        let title = (error == nil) ? "Success" : "Error"
        let message = (error == nil) ? "Video was saved" : "Video failed to save"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: Button Action
extension MainViewController {
    @IBAction func addFirstVideoDidTap(_ sender: Any) {
        openVideoBrowser(sourceType: .savedPhotosAlbum, delegate: self)
        didSelectVideo = { [weak self]  firstSelectedVideoURL in
            guard let self = self else { return }
            self.firstVideoUrl = firstSelectedVideoURL
            self.setUpFirstPlayerItem()
            guard let selectedImg = generateThumbnail(path: firstSelectedVideoURL) else { return }
            self.firstThumb.image = selectedImg
            guard var duration = self.firstPlayer.currentItem?.asset.duration.seconds else { return }
            duration.round()
            self.firstDuration.text = "0:\(duration.secondsToString)"
            self.setupPlaySaveButton()
        }
    }
    
    @IBAction func addSecondVideoDidTap(_ sender: Any) {
        openVideoBrowser(sourceType: .savedPhotosAlbum, delegate: self)
        didSelectVideo = { [weak self]  secondSelectedVideoURL in
            guard let self = self else { return }
            self.secondVideoUrl = secondSelectedVideoURL
            self.setUpSecondPlayerItem()
            guard let selectedImg = generateThumbnail(path: secondSelectedVideoURL) else { return }
            self.secondThumb.image = selectedImg
            guard var duration = self.secondPlayer.currentItem?.asset.duration.seconds else { return }
            duration.round()
            self.secondDurationLabel.text = "0:\(duration.secondsToString)"
            self.setupPlaySaveButton()
        }
        
    }
    
    func setupPlaySaveButton() {
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }
            guard let _ = self.firstVideoUrl, let _ = self.secondVideoUrl else {
                self.playButton.alpha = 0
                self.saveButton.alpha = 0
                return
            }
            self.playButton.alpha = 1
            self.saveButton.alpha = 1
        }
    }
    
    @IBAction func playBtnDidTap(_ sender: Any) {
        guard let _ = firstVideoUrl, let _ = secondVideoUrl else { return }
        setUpPlayerItem()
        metalView.videoMaker?.startSession()
        firstPlayer.play()
        displayLink.isPaused = false
    }
}

// MARK: AVPlayer
extension MainViewController {
        
    func setUpFirstPlayerItem() {
        guard let firstUrl = firstVideoUrl else { return }
        let firstAsset = AVURLAsset(url: firstUrl)
        firstPlayerItem = AVPlayerItem(asset: firstAsset)
        firstPlayerItem.add(firstPlayerItemVideoOutput)
        firstPlayer.replaceCurrentItem(with: firstPlayerItem)
    }
    
    func setUpSecondPlayerItem() {
        guard let secondUrl = secondVideoUrl else { return }
        let secondAsset = AVURLAsset(url: secondUrl)
        secondPlayerItem = AVPlayerItem(asset: secondAsset)
        secondPlayerItem.add(secondPlayerItemVideoOutput)
        secondPlayer.replaceCurrentItem(with: secondPlayerItem)
    }
    
    private func setUpPlayerItem() {
        removeObserver()
        addAVPlayerObserver()
        metalView.overlapDuration = self.overlapDuration
    }
    
    func addAVPlayerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(secondVideoDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: secondPlayer.currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(firstVideoDidPlayToEnd), name: .AVPlayerItemDidPlayToEndTime, object: firstPlayer.currentItem)
    }
    
    @objc func secondVideoDidPlayToEnd() {
        secondPlayer.pause()
        displayLink.isPaused = true
        removeObserver()
    }
    
    @objc func firstVideoDidPlayToEnd() {
        firstPlayer.pause()
    }
    
    func removeObserver() {
        NotificationCenter.default.removeObserver(self)
    }
}


extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else { return }
        
        dismiss(animated: true) {
            self.didSelectVideo?(url)
        }
    }
    
    func openVideoBrowser(sourceType: UIImagePickerController.SourceType, delegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            return
        }
        
        let pickerVC = UIImagePickerController()
        pickerVC.sourceType = sourceType
        pickerVC.mediaTypes = [kUTTypeMovie as String]
        pickerVC.allowsEditing = false
        pickerVC.delegate = delegate
        self.present(pickerVC, animated: true, completion: nil)
    }
}

func generateThumbnail(path: URL) -> UIImage? {
    do {
        let asset = AVURLAsset(url: path, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        return thumbnail
    } catch let error {
        print("*** Error generating thumbnail: \(error.localizedDescription)")
        return nil
    }
}
