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

@objc public class PlayerViewController: NSObject, AVAssetResourceLoaderDelegate {
    
    
    //****************************************************
    // MARK: - Properties
    //****************************************************
    
    // Attempt to load and test these asset keys before playing
    let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    var mediaPlayer: AVPlayerViewController = AVPlayerViewController()
    var timeObserverToken: Any?
    
    var delegate:PlayerViewControllerDelegate! = nil

    var queuePlayer: AVQueuePlayer?

    var urlAsset: AVURLAsset? {
        didSet {
            guard let newAsset = urlAsset else { return }
            asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
    private var playerItem: AVPlayerItem? = nil {
        willSet {
            if playerItem == nil {
                removeObservers()
            }
        }
        didSet {
            /*
             If needed, configure player item here before associating it with a player.
             (example: adding outputs, setting text style rules, selecting media options)
             */
            if playerItem != nil {
                
                if (queuePlayer?.canInsert(self.playerItem!, after: nil))! {
                    queuePlayer?.insert(self.playerItem!, after: nil)
                    
                    // let playerItem      = AVPlayerItem(asset: urlAsset!)
                    
                    //queuePlayer         = AVQueuePlayer(playerItem: playerItem)
                    mediaPlayer.player  = queuePlayer
                    
                }
                // mediaPlayer.player?.replaceCurrentItem(with: self.playerItem)
                prepareToPlay()
            }
        }
    }
    
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
    
    deinit {
        cleanUp()
        delegate = nil
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    //****************************************************
    //MARK: - Priavate methods
    //****************************************************
    
    private func setupPlayerPeriodicTimeObserver() {
         // Only add the time observer if one hasn't been created yet.
         guard timeObserverToken == nil else { return }
       
        // Make sure we don't have a strong reference cycle by only capturing self as weak.
        let interval        = CMTimeMake(1, 1)
        timeObserverToken   = mediaPlayer.player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
            let timeElapsed  = Float(CMTimeGetSeconds(time))
            
            self.delegate!.playerTimeUpdate(time:Double(timeElapsed))
        }
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            mediaPlayer.player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func addObservers() {
        // Register as an observer of the player item's status property
        playerItem?.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerViewControllerKVOContext)
        
        
        playerItem?.addObserver(self,
                                                     forKeyPath: #keyPath(AVPlayerItem.duration),
                                                     options: [.old, .new],
                                                     context: &playerViewControllerKVOContext)

        mediaPlayer.player?.addObserver(self,
                                                     forKeyPath: #keyPath(AVPlayer.rate),
                                                     options: [.old, .new],
                                                     context: &playerViewControllerKVOContext)
        
        mediaPlayer.player?.addObserver(self,
                                        forKeyPath: #keyPath(AVPlayer.currentItem),
                                        options: [.old, .new],
                                        context: &playerViewControllerKVOContext)
    }
    
     func removeObservers() {
        
        if (playerItem != nil) {
            playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), context: &playerViewControllerKVOContext)
            playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerViewControllerKVOContext)
            mediaPlayer.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate), context: &playerViewControllerKVOContext)
            mediaPlayer.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem), context: &playerViewControllerKVOContext)

            cleanUpPlayerPeriodicTimeObserver()
        }
    }
    
    func prepareToPlay() {
   // NotificationCenter.default.addObserver(self, selector: Selector(("playerDidFinishPlaying:")), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        addObservers()
        setupPlayerPeriodicTimeObserver()
    }

    func cleanUp() {
        pause()
        queuePlayer?.removeAllItems()
        playerItem  = nil
        urlAsset    = nil
        queuePlayer = nil
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        if (queuePlayer?.items().isEmpty)! {
            print("Play queue emptied out due to bad player item. End looping")
            removeObservers()
            cleanUp()
            initPlayer(urlString: "")
            self.delegate!.playerFrameRateChanged(frameRate: 0)
        }
    }
    
    // MARK: - Error Handling
    
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
    }
    
    func asynchronouslyLoadURLAsset(_ newAsset: AVURLAsset) {
        /*
         Using AVAsset now runs the risk of blocking the current thread (the
         main UI thread) whilst I/O happens to populate the properties. It's
         prudent to defer our work until the properties we need have been loaded.
         */
        newAsset.loadValuesAsynchronously(forKeys: assetKeysRequiredToPlay) {
            /*
             The asset invokes its completion handler on an arbitrary queue.
             To avoid multiple threads using our internal state at the same time
             we'll elect to use the main thread at all times, let's dispatch
             our handler to the main queue.
             */
            DispatchQueue.main.sync {
                /*
                 `self.asset` has already changed! No point continuing because
                 another `newAsset` will come along in a moment.
                 */
                guard newAsset == self.urlAsset else { return }
                
                /*
                 Test whether the values of each of the keys we need have been
                 successfully loaded.
                 */
                for key in self.assetKeysRequiredToPlay {
                    var error: NSError?
                    
                    if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                        let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                        
                        let message = String.localizedStringWithFormat(stringFormat, key)
                        
                        self.handleErrorWithMessage(message, error: error)
                        
                        return
                    }
                }
                
                // We can't play this asset.
                if !newAsset.isPlayable || newAsset.hasProtectedContent {
                    let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                    
                    self.handleErrorWithMessage(message)
                    
                    return
                }
                
                /*
                 We can play this asset. Create a new `AVPlayerItem` and make
                 it our player's current item.
                 */
                self.playerItem = AVPlayerItem(asset: newAsset)
            }
        }
    }
    
    //****************************************************
    // MARK: - Public methods
    //****************************************************
    
    
    public func initPlayer(urlString: String) {
        mediaPlayer.showsPlaybackControls = false

        
        ///////////Demo Urls//////////////////////////////////////
        //let urlString = Bundle.main.path(forResource: "trailer_720p", ofType: "mov")!
        var urlString   = Bundle.main.path(forResource: "ElephantSeals", ofType: "mov")!
        let localURL    = true
    
        
        // MARK: - m3u8 urls
        // let urlString = Bundle.main.path(forResource: "bipbopall", ofType: "m3u8")!
        
        // let urlString     = "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
      // var urlString     = "https://dl.dropboxusercontent.com/u/7303267/website/m3u8/index.m3u8";
        // let urlString     = "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
        
        //  let urlString = "http://playertest.longtailvideo.com/adaptive/oceans_aes/oceans_aes.m3u8" //(AES encrypted)
        //let urlString = "https://devimages.apple.com.edgekey.net/samplecode/avfoundationMedia/AVFoundationQueuePlayer_HLS2/master.m3u8" //(Reverse playback)
        //let urlString = "http://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8" //(4K)
        //let urlString = "http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch3/appleman.m3u8" //((LIVE TV)
        
        // MARK: - App urls
       //var urlString = "http://nmstream2.clearhub.tv/nmdcMaa/20130713/others/30880d62-2c5b-4487-8ff1-5794d086bea7.mp4"
        
        
        //////////////////////////////////////////
        
        
        
        var urlStr = urlString as NSString
        
        if urlStr.range(of:".m3u8").location == NSNotFound {
            urlStr = urlString.replacingOccurrences(of:"http", with:"playlist") as NSString
        }
        urlString = urlStr as String
        
        var url = URL.init(string: urlString)!
        if (localURL) {
            url =  URL(fileURLWithPath: urlString)
        }
        print("Streming URL:",urlString)

        //First way and working
        // Create asset to be played
       /* let asset = AVAsset(url: url)
        
        // Create a new AVPlayerItem with the asset and an array of asset keys to be automatically loaded
        let playerItem = AVPlayerItem(asset: asset,
                                      automaticallyLoadedAssetKeys:assetKeysRequiredToPlay)
        
        // Associate the player item with the player
        mediaPlayer.player = AVPlayer(playerItem: playerItem)
        prepareToPlay()*/
        
        let headers : [String: String] = ["User-Agent": "iPad"]

        //Second way
        
       /* let urlAsset        = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset.resourceLoader
        resourceLoader.setDelegate(self, queue:DispatchQueue.main)
        
        let playerItem      = AVPlayerItem(asset: urlAsset)
        // Associate the player item with the player
        mediaPlayer.player = AVPlayer(playerItem: playerItem)
        //mediaPlayer.player  =  AVQueuePlayer(playerItem: playerItem)
        self.prepareToPlay()*/

        
        // 3rd way
        queuePlayer         = AVQueuePlayer()
        urlAsset            = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset?.resourceLoader
        resourceLoader?.setDelegate(self, queue:DispatchQueue.main)
        
//        // Associate the player item with the player
       // let playerItem      = AVPlayerItem(asset: urlAsset!)
      
        //queuePlayer         = AVQueuePlayer(playerItem: playerItem)
        //mediaPlayer.player  = queuePlayer
       // let playerItem      = AVPlayerItem(asset: urlAsset!)
       // mediaPlayer.player  = AVQueuePlayer(playerItem: playerItem)
        //self.prepareToPlay()
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
                self.handleErrorWithMessage(mediaPlayer.player?.currentItem?.error?.localizedDescription)

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
                            self.handleErrorWithMessage(mediaPlayer.player?.currentItem?.error?.localizedDescription)
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        self.handleErrorWithMessage(mediaPlayer.player?.currentItem?.error?.localizedDescription)
                        return
                    }
                    
                    /*
                     The player item is ready to play,
                     */
                    self.delegate!.playerReadyToPlay()
                    print("canPlayReverse:\(mediaPlayer.player?.currentItem?.canPlayReverse)")

                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.duration) {
 
        }
        else if keyPath == #keyPath(AVPlayer.rate) {
            // Update playPauseButton type.
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue
            self.delegate!.playerFrameRateChanged(frameRate: newRate)
        }
        else if keyPath == #keyPath(AVPlayer.currentItem) {
            guard let player = queuePlayer else { return }
            
            if queuePlayer?.rate == -1.0 {
                return
            }
            
            if player.items().isEmpty {
                print("Play queue emptied out due to bad player item. End looping")
                 removeObservers()
                 cleanUp()
                 initPlayer(urlString: "")
                self.delegate!.playerFrameRateChanged(frameRate: 0)

            }
            else {
                // If `loopCount` has been set, check if looping needs to stop.
               /* if numberOfTimesToPlay > 0 {
                    numberOfTimesPlayed = numberOfTimesPlayed + 1
                    
                    if numberOfTimesPlayed >= numberOfTimesToPlay {
                        print("Looped \(numberOfTimesToPlay) times. Stopping.");
                        stop()
                    }
                }*/
                
                /*
                 Append the previous current item to the player's queue. An initial
                 change from a nil currentItem yields NSNull here. Check to make
                 sure the class is AVPlayerItem before appending it to the end
                 of the queue.
                 */
                if let itemRemoved = change?[.oldKey] as? AVPlayerItem {
                    itemRemoved.seek(to: kCMTimeZero)
                    removeObservers()
                    //cleanUp()
                    queuePlayer?.insert(itemRemoved, after: nil)
                    addObservers()
                }
            }
        }
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
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
    
    public func reversePlayback() {
        
        if let reversePlay = mediaPlayer.player!.currentItem?.canPlayReverse  {
            print("reversePlay = \(reversePlay)")
            if (mediaPlayer.player!.rate == 0) {
                play()
                mediaPlayer.player!.rate = -1.0
            }
        }
    }
    
    
    //****************************************************
    // MARK: - AVAssetResourceLoaderDelegate methods
    //****************************************************
 
    // FPS Key Fetch for Persistent Keys
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource
        loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        print("shouldWaitForLoadingOfRequestedResource called...")

       /* if loadingRequest.request.url?.scheme == "skd" {
            let persistentContentKeyContext = Data(contentsOf: keySaveLocation)!
            loadingRequest.contentInformationRequest!.contentType = AVStreamingKeyDeliveryPersistentContentKeyType
            
            loadingRequest.dataRequest!.respond(with: persistentContentKeyContext)
            loadingRequest.finishLoading()
            return true
        }
        return false*/
        return true
    }
 
}
