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
    var timeObserverToken: AnyObject?
    var delegate:PlayerViewControllerDelegate! = nil
    
    var queuePlayer = AVQueuePlayer()

    var urlAsset: AVURLAsset? {
        didSet {
            guard let newAsset = urlAsset else { return }
            asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
    private var playerItem: AVPlayerItem? = nil {
        didSet {
            /*
             If needed, configure player item here before associating it with a player.
             (example: adding outputs, setting text style rules, selecting media options)
             */
            if (playerItem == nil) {
                removeObservers()
            } else {
                if (queuePlayer.canInsert(self.playerItem!, after: nil)) {
                    queuePlayer.insert(self.playerItem!, after: nil)
                }
                mediaPlayer.player?.replaceCurrentItem(with: self.playerItem)
                
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
        
        if (mediaPlayer.player?.currentItem) != nil {
            mediaPlayer.player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), context: &playerViewControllerKVOContext)
            mediaPlayer.player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerViewControllerKVOContext)
            mediaPlayer.player?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate), context: &playerViewControllerKVOContext)
        }
    }
    
    func prepareToPlay() {
        addObservers()
        setupPlayerPeriodicTimeObserver()
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
        //let urlString = Bundle.main.path(forResource: "ElephantSeals", ofType: "mov")!
        let localURL = false
    
        
        // MARK: - m3u8 urls
        // let urlString = Bundle.main.path(forResource: "bipbopall", ofType: "m3u8")!
        
        // let urlString     = "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
       var urlString     = "https://dl.dropboxusercontent.com/u/7303267/website/m3u8/index.m3u8";
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
        print("Streming URL:",urlString)
        
        var url = URL.init(string: urlString)!
        if (localURL) {
            url =  URL(fileURLWithPath: urlString)
        }
        
        //First way and working
        // Create asset to be played
       /* let asset = AVAsset(url: url)
        
        // Create a new AVPlayerItem with the asset and an array of asset keys to be automatically loaded
        let playerItem = AVPlayerItem(asset: asset,
                                      automaticallyLoadedAssetKeys:assetKeysRequiredToPlay)
        
        // Associate the player item with the player
        mediaPlayer.player = AVPlayer(playerItem: playerItem)
        prepareToPlay()*/
        
        //Second way
        let headers : [String: String] = ["User-Agent": "iPad"]
        
        /*let urlAsset        = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset.resourceLoader
        resourceLoader.setDelegate(self, queue:DispatchQueue.main)
        
        let playerItem      = AVPlayerItem(asset: urlAsset)
        // Associate the player item with the player
       // mediaPlayer.player = AVPlayer(playerItem: playerItem)
        mediaPlayer.player  =  AVQueuePlayer(playerItem: playerItem)
        self.prepareToPlay()*/

        
        // 3rd way
        urlAsset            = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset?.resourceLoader
        resourceLoader?.setDelegate(self, queue:DispatchQueue.main)
        
        // Associate the player item with the player
        queuePlayer = AVQueuePlayer(playerItem: playerItem)

        mediaPlayer.player  = queuePlayer

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
    
    public func reversePlayback() {
        
        if let reversePlay = mediaPlayer.player!.currentItem?.canPlayReverse  {
        //mediaPlayer.player!.seek(to: mediaPlayer.player!.currentItem!.asset.duration)
        print("reversePlay = \(reversePlay)")
        mediaPlayer.player!.rate = -1.0
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
