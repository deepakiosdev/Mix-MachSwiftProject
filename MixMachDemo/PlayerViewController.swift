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
    func playerFrameRateChanged(frameRate:Float)
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
    
    
    var timeObserverToken: Any?
    
    var delegate:PlayerViewControllerDelegate! = nil
    
    ////
    var mediaPlayer: AVPlayerViewController! {
            didSet {
                mediaPlayer.showsPlaybackControls   = false
        }
    }

    ////
    var queuePlayer: AVQueuePlayer? {
        didSet {
            if let player = queuePlayer {
                mediaPlayer.player = player
            }
        }
    }

    ////
    var urlAsset: AVURLAsset? {
        didSet {
            guard let newAsset = urlAsset else { return }
            asynchronouslyLoadURLAsset(newAsset)
        }
    }
    
    ////
    private var currentItem: AVPlayerItem? = nil {
        willSet {
            if currentItem == nil {
                //removeObservers()
            }
        }
        didSet {
            /*
             If needed, configure player item here before associating it with a player.
             (example: adding outputs, setting text style rules, selecting media options)
             */
            if currentItem != nil && queuePlayer != nil {
                
                if (queuePlayer?.canInsert(self.currentItem!, after: nil))! {
                    queuePlayer?.insert(self.currentItem!, after: nil)
                }
                prepareToPlay()
            }
        }
    }
    
    ////
    var frameRate: Int32!
    
    ////
    var isPlaying : Bool {
        get {
            if (queuePlayer?.rate != 0 && queuePlayer?.error == nil) {
                return true
            }
            return false
        }
    }
    
    ////
    var rate: Float {
        get {
            return (queuePlayer?.rate)!
        }
        
        set {
            queuePlayer?.rate = newValue
            print("Player rate:\(queuePlayer?.rate)")
        }
    }
    
    ////
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(queuePlayer!.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(newValue, 1)
            queuePlayer?.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        }
    }
    
    ////
    var duration: Double {
        guard let currentItem = queuePlayer?.currentItem else { return 0.0 }
        
        return CMTimeGetSeconds(currentItem.duration)
    }
    
    /*
     A formatter for individual date components used to provide an appropriate
     value for the `startTimeLabel` and `durationLabel`.
     */
   let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter                       = DateComponentsFormatter()
        formatter.zeroFormattingBehavior    = .dropMiddle //.pad
        formatter.allowedUnits              = [.hour, .minute, .second]
        
        return formatter
    }()


    
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
        timeObserverToken   = queuePlayer?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
            let timeElapsed  = Float(CMTimeGetSeconds(time))
            
            self.delegate!.playerTimeUpdate(time:Double(timeElapsed))
        }
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            queuePlayer?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func addObservers() {
        // Register as an observer of the player item's status property
        if (currentItem != nil) {
            currentItem?.addObserver(self,
                                    forKeyPath: #keyPath(AVPlayerItem.status),
                                    options: [.old, .new],
                                    context: &playerViewControllerKVOContext)
            
            
            currentItem?.addObserver(self,
                                    forKeyPath: #keyPath(AVPlayerItem.duration),
                                    options: [.old, .new],
                                    context: &playerViewControllerKVOContext)
        }

        if (queuePlayer != nil) {
            queuePlayer?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayer.rate),
                                     options: [.old, .new],
                                     context: &playerViewControllerKVOContext)
            
            queuePlayer?.addObserver(self,
                                     forKeyPath: #keyPath(AVPlayer.currentItem),
                                     options: [.old, .new],
                                     context: &playerViewControllerKVOContext)
        }
    }
    
     func removeObservers() {
        if (currentItem != nil) {
            currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), context: &playerViewControllerKVOContext)
            currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: &playerViewControllerKVOContext)
        }
        
        if (queuePlayer != nil) {
            queuePlayer?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate), context: &playerViewControllerKVOContext)
            queuePlayer?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem), context: &playerViewControllerKVOContext)
        }
        cleanUpPlayerPeriodicTimeObserver()

    }
    
    func prepareToPlay() {
        frameRate = getAssetFrameRate()
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: currentItem)
        addObservers()
        setupPlayerPeriodicTimeObserver()
    }

    func cleanUp() {
        pause()
        currentTime = 0.0
        removeObservers()
        NotificationCenter.default.removeObserver(self)
        queuePlayer?.removeAllItems()
        urlAsset    = nil
        currentItem = nil
        queuePlayer = nil
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        if (queuePlayer?.items().isEmpty)! == false && (duration != 0.0) {
            print("Play queue emptied out due to bad player item. End looping")
            self.delegate!.playerFrameRateChanged(frameRate: 0)
            self.delegate!.playerTimeUpdate(time:Double(0.0))
            cleanUp()
            initPlayer(urlString: "")
        }
    }
    
    func getAssetFrameRate() -> Int32 {
        frameRate = 0
        for track in (currentItem?.tracks)! {
            
            if(track.assetTrack.mediaType == AVMediaTypeVideo) {
                frameRate = Int32(track.currentVideoFrameRate)
                break
            }
        }
        
        if (frameRate == 0) {
            
            if (currentItem?.asset != nil) {
                if let videoTrack = currentItem?.asset.tracks(withMediaType: AVMediaTypeVideo).last {
                    frameRate = Int32(videoTrack.nominalFrameRate)
                }
            }
        }
        
        if (frameRate == 0) {
            frameRate = 25
        }
        return frameRate
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
                //self.currentItem = AVPlayerItem(asset: newAsset)
                self.currentItem = AVPlayerItem(asset: newAsset, automaticallyLoadedAssetKeys:self.assetKeysRequiredToPlay)
                self.currentItem?.seek(to: kCMTimeZero)
            }
        }
    }
    
    //****************************************************
    // MARK: - Public methods
    //****************************************************
    
    
    // MARK: - Player related methods

    public func initPlayer(urlString: String) {
        
        ///////////Demo Urls//////////////////////////////////////
        //let urlString = Bundle.main.path(forResource: "trailer_720p", ofType: "mov")!
       // var urlString   = Bundle.main.path(forResource: "ElephantSeals", ofType: "mov")!
        let localURL    = false
    
        // MARK: - m3u8 urls
        // let urlString = Bundle.main.path(forResource: "bipbopall", ofType: "m3u8")!
        
        //var urlString     = "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
        var urlString     = "https://dl.dropboxusercontent.com/u/7303267/website/m3u8/index.m3u8";
        //var urlString     = "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
        
        //var urlString = "http://playertest.longtailvideo.com/adaptive/oceans_aes/oceans_aes.m3u8" //(AES encrypted)
        //let urlString = "https://devimages.apple.com.edgekey.net/samplecode/avfoundationMedia/AVFoundationQueuePlayer_HLS2/master.m3u8" //(Reverse playback)
        //let urlString = "http://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8" //(4K)
        //let urlString = "http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch3/appleman.m3u8" //((LIVE TV)
        //var urlString  = "http://cdn-fms.rbs.com.br/vod/hls_sample1_manifest.m3u8"
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
        queuePlayer = AVPlayer(playerItem: playerItem)
        prepareToPlay()*/
        
        let headers : [String: String] = ["User-Agent": "iPad"]

        //Second way
        
       /* let urlAsset        = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset.resourceLoader
        resourceLoader.setDelegate(self, queue:DispatchQueue.main)
        
        let playerItem      = AVPlayerItem(asset: urlAsset)
        // Associate the player item with the player
        queuePlayer = AVPlayer(playerItem: playerItem)
        //queuePlayer  =  AVQueuePlayer(playerItem: playerItem)
        self.prepareToPlay()*/

        
        // 3rd way
        queuePlayer          = AVQueuePlayer()
        //mediaPlayer.player  = queuePlayer
        urlAsset            = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        let resourceLoader  = urlAsset?.resourceLoader
        resourceLoader?.setDelegate(self, queue:DispatchQueue.main)
        
//        // Associate the player item with the player
       // let playerItem      = AVPlayerItem(asset: urlAsset!)
      
        //queuePlayer         = AVQueuePlayer(playerItem: playerItem)
        //queuePlayer  = queuePlayer
       // let playerItem      = AVPlayerItem(asset: urlAsset!)
       // queuePlayer  = AVQueuePlayer(playerItem: playerItem)
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
                self.handleErrorWithMessage(queuePlayer?.currentItem?.error?.localizedDescription)

            }
            else if newStatus == .readyToPlay {
                
                if let asset = queuePlayer?.currentItem?.asset {

                    /*
                     First test whether the values of `assetKeysRequiredToPlay` we need
                     have been successfully loaded.
                     */
                    for key in assetKeysRequiredToPlay {
                        var error: NSError?
                        if asset.statusOfValue(forKey: key, error: &error) == .failed {
                            self.handleErrorWithMessage(queuePlayer?.currentItem?.error?.localizedDescription)
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        self.handleErrorWithMessage(queuePlayer?.currentItem?.error?.localizedDescription)
                        return
                    }
                    
                    /*
                     The player item is ready to play,
                     */
                    self.delegate!.playerReadyToPlay()
                    print("canPlayReverse:\(queuePlayer?.currentItem?.canPlayReverse)")
                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.duration) {
 
        }
        else if keyPath == #keyPath(AVPlayer.rate) {
            // Update playPauseButton type.
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
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
                    cleanUp()
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
        if queuePlayer?.rate != 1.0 {
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
        queuePlayer?.play()
    }
    
    public func pause() {
        queuePlayer?.pause()
    }
    
    // TODO: For |reversePlayback| and |fastForwardPlayback| put check canPlayFastForward, canPlaySlowForward, canPlayReverse etc... and make a single method
    public func playReverse() {
        // Rewind no faster than -2.0.
      var playerRate = max((queuePlayer?.rate)! - 0.5, -2.0)
        if (playerRate >= 0) {
          playerRate = -0.5
        }
        rate = playerRate
    }
    
    public func playeForward() {
        //Fast forward no faster than 2.0.
        var playerRate = min((queuePlayer?.rate)! + 0.5, 2.0)
        if (rate <= 0) {
            playerRate = 0.5
        }
        rate = playerRate

    }
    
    /*
     * |numberOfFrame| +ve value means move forward and -ve backwoard
     */
    public func stepFrames(byCount numberOfFrame:Int) {
        currentItem?.cancelPendingSeeks()
        print("canStepForward\(currentItem?.canStepForward)")
        print("canStepBackward\(currentItem?.canStepBackward)")

        //currentItem?.step(byCount: numberOfFrame)
        let currentTime         = currentItem?.currentTime()
        var currentTimeScale    = CMTimeConvertScale(currentTime!, frameRate, CMTimeRoundingMethod.default)
        
        if (numberOfFrame > 0) {
            currentTimeScale.value += numberOfFrame
        } else {
            currentTimeScale.value -= numberOfFrame
        }
        
        queuePlayer?.seek(to: currentTimeScale, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (Bool) in
            self.pause()
        })
    }

    
    public func stepSeconds(byCount numberOfSecond:Int64) {
        pause()
        currentItem?.cancelPendingSeeks()
        let seconds = CMTimeMake(numberOfSecond, frameRate)
        //queuePlayer?.seek(to: seconds) // Optimized for speed
        
        if let currentTime = queuePlayer?.currentTime() {
            
            var seekTime = kCMTimeZero
            if numberOfSecond > 0 {
                seekTime = CMTimeAdd(currentTime, seconds)
            } else {
                seekTime = CMTimeSubtract(currentTime, seconds)
            }
            
            queuePlayer?.seek(to: seekTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (Bool) in
                self.pause()
            })
        }
        
    }
    
    
    
    public func moveTo(numberOfSecond seconds:Int64) {
        
        /*let seconds = CMTimeMake(seconds, 1)
        player?.seekToTime(fiveSecondsIn) // Optimized for speed
        player?.seekToTime(fiveSecondsIn, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) // Optimized for precision
        
        if let currentTime = player?.currentTime() {
            let fiveSecondsAhead = CMTimeAdd(currentTime, fiveSecondsIn)
            player?.seekToTime(fiveSecondsAhead)
        }*/

    }
    // MARK: - Time utility methods

    public func getTimeString(time: Float) -> String {
        let components      = NSDateComponents()
        components.second   = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }

    public func getTimeCodeFromSeonds(time: Float) -> String {
    
        let sec             = Int(time) % 60
        let min             = (Int(time)/60) % 60
        let hours           = (Int(time)/3600) % 60
        let currentTime     = CMTimeMakeWithSeconds(Float64(time), frameRate)
        let currentTimeF    = CMTimeConvertScale(currentTime, frameRate, CMTimeRoundingMethod.default)
        let frame           = fmodf(Float(currentTimeF.value), Float(frameRate))
        return String(format: "%02d:%02d:%02d:%02d", hours, min, sec, Int(frame))
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
