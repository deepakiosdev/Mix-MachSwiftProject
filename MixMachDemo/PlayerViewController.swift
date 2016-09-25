//
//  PlayerViewController.swift
//  Mix-MachSwiftProject
//
//  Created by Deepak on 24/09/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit

/*
	KVO context used to differentiate KVO callbacks for this class versus other
	classes in its class hierarchy.
 */
private var playerViewControllerKVOContext  = 0

/*!
	@protocol	PlayerViewControllerDelegate
	@abstract	A protocol for delegates of PlayerViewController.
 */
@objc protocol PlayerViewControllerDelegate {
    func playerTimeUpdate(time:Double)
    func playerReadyToPlay()
    func playerFrameRateChanged(frameRate:Double)
}

@objc public class PlayerViewController: NSObject {
    
    
    //****************************************************
    // MARK: - Properties
    //****************************************************
    
    // Attempt to load and test these asset keys before playing
    let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    var mediaPlayer: AVPlayerViewController = AVPlayerViewController()
    var timeObserverToken: AnyObject?
    var delegate:PlayerViewControllerDelegate! = nil
    
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(mediaPlayer.player!.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            mediaPlayer.player?.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    var duration: Double {
        guard let currentItem = mediaPlayer.player?.currentItem else { return 0.0 }
        
        return CMTimeGetSeconds(currentItem.duration)
    }
   
    //****************************************************
    // MARK: - Life Cycle Methods
    //****************************************************
    override init() {
        
    }
    
//    override public func viewDidLoad() {
//        super.viewDidLoad()
//        // Do any additional setup after loading the view, typically from a nib.
//    }
//    
//    override public func didReceiveMemoryWarning() {
//        super.didReceiveMemoryWarning()
//        // Dispose of any resources that can be recreated.
//    }
//    
//    
//    override public func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(true)
//    }
//    
//    override public func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(true)
//        
//    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    deinit {
        removeObservers()
    }
    
    //****************************************************
    //MARK: - Priavate methods
    //****************************************************
    
    private func setupPlayerPeriodicTimeObserver() {
        // Only add the time observer if one hasn't been created yet.
        guard timeObserverToken == nil else { return }
        let time = CMTimeMake(1, 1)
        // Use a weak self variable to avoid a retain cycle in the block.
        timeObserverToken =  mediaPlayer.player?.addPeriodicTimeObserver(forInterval: time, queue:DispatchQueue.main) {
            [weak self] time in
            self?.delegate!.playerTimeUpdate(time:(self?.currentTime)!)
            } as AnyObject?
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            mediaPlayer.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func addObservers() {
        // Register as an observer of the player item's status property
        mediaPlayer.player?.currentItem?.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerViewControllerKVOContext)
        
        
        mediaPlayer.player?.currentItem?.addObserver(self,
                                                     forKeyPath: #keyPath(AVPlayerItem.duration),
                                                     options: [.old, .new],
                                                     context: &playerViewControllerKVOContext)

        mediaPlayer.player?.addObserver(self,
                                                     forKeyPath: #keyPath(AVPlayer.rate),
                                                     options: [.old, .new],
                                                     context: &playerViewControllerKVOContext)
    }
    
     func removeObservers() {
        
        mediaPlayer.player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), context: &playerViewControllerKVOContext)
        mediaPlayer.player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerViewControllerKVOContext)
        mediaPlayer.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate), context: &playerViewControllerKVOContext)

    }
    
    func prepareToPlay() {
        
        addObservers()
        setupPlayerPeriodicTimeObserver()
        mediaPlayer.showsPlaybackControls = false
    }

    
    // MARK: - Error Handling
    
    func handleError(_ error: NSError?) {
        print("error:\(error)")
    }
    
    //****************************************************
    // MARK: - Public methods
    //****************************************************
    
    
    public func initWithUrl(url: String) {
    //let url = Bundle.main.path(forResource: "trailer_720p", ofType: "mov")!
       let url     = "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
      //let url     = "https://dl.dropboxusercontent.com/u/7303267/website/m3u8/index.m3u8";
      // let url     = "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
        
        
        // Create asset to be played
        let asset = AVAsset(url: URL.init(string: url)!)

        // Create a new AVPlayerItem with the asset and an
        // array of asset keys to be automatically loaded
        let playerItem = AVPlayerItem(asset: asset,
                                  automaticallyLoadedAssetKeys:assetKeysRequiredToPlay)
        
        
        // Associate the player item with the player
        mediaPlayer.player = AVPlayer(playerItem: playerItem)
       // mediaPlayer.player = AVPlayer(url: URL(fileURLWithPath: url))
        prepareToPlay()

    }
   
    override public func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        print("keyPath:\(keyPath), change:\(change)")
        // Only handle observations for the playerViewControllerKVOContext
        guard context == &playerViewControllerKVOContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let newStatus: AVPlayerItemStatus
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            if newStatus == .failed {
                handleError(mediaPlayer.player?.currentItem?.error as NSError?)
            }
            else if newStatus == .readyToPlay {
                
                if let asset = mediaPlayer.player?.currentItem?.asset {
                    
                    /*
                     First test whether the values of `assetKeysRequiredToPlay` we need
                     have been successfully loaded.
                     */
                    for key in assetKeysRequiredToPlay {
                        var error: NSError?
                        if asset.statusOfValue(forKey: key, error: &error) == .failed {
                            self.handleError(error!)
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        handleError(nil)
                        return
                    }
                    
                    /*
                     The player item is ready to play,
                     setup picture in picture.
                     */
                    self.delegate!.playerReadyToPlay()

                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.duration) {
           
            /*let newDuration: CMTime
            if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
                newDuration = newDurationAsValue.timeValue
            }
            else {
                newDuration = kCMTimeZero
            }
            let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
            let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
            */
            //self.delegate!.playerReadyToPlay()

        }
        else if keyPath == #keyPath(AVPlayer.rate){
            // Update playPauseButton type.
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue
            
            self.delegate!.playerFrameRateChanged(frameRate: newRate)
        }
    }

    public func playPause() {
        if mediaPlayer.player?.rate != 1.0 {
            // Not playing foward, so play.
            if currentTime == duration {
                // At end, so got back to beginning.
                currentTime = 0.0
            }
            play()
        }
        else {
            // Playing, so pause.
            pause()
        }
    }
    
    public func play() {
        mediaPlayer.player?.play()
    }
    
    public func pause() {
        mediaPlayer.player?.pause()
    }
}
