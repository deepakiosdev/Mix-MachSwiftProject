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
    func buffering()
    func bufferingFinsihed()
}



@objc public class PlayerViewController: NSObject, AVAssetResourceLoaderDelegate {
    
    
    //****************************************************
    // MARK: - Properties
    //****************************************************
    
    //MARK: - Constants
    // Attempt to load and test these asset keys before playing
    let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    let CUSTOM_SCHEME =  "cspum3u8"
    
    //MARK: - Variables
    var timeObserverToken: Any?
    var delegate: PlayerViewControllerDelegate! = nil
    var mediaPlayer: AVPlayerViewController!
    var frameRate: Float!
    var previousRate: Float = 0.0
    var isPlayerInitilaized = false
    var isAutoPlay          = false
    var queuePlayer         = AVQueuePlayer()
    var urlAsset: AVURLAsset?
    var curAudioTrack       = ""
    var availableAudioTracks = [AudioTrack]()


    //MARK: - Computed Properties
    ////
    @objc private var currentItem: AVPlayerItem? = nil {
        didSet {
            /*
             If needed, configure player item here before associating it with a player.
             (example: adding outputs, setting text style rules, selecting media options)
             */
            if currentItem != nil {
                if (queuePlayer.canInsert(self.currentItem!, after: nil)) {
                    queuePlayer.insert(self.currentItem!, after: nil)
                }
                prepareToPlay()
                
            }
        }
    }
    
    ////
    var isPlaying : Bool {
        get {
            if (queuePlayer.rate != 0 && queuePlayer.error == nil) {
                return true
            }
            return false
        }
    }
    
    ////
    var rate: Float {
        get {
            return (queuePlayer.rate)
        }
        set {
            self.previousRate = newValue
            queuePlayer.rate = newValue
            print("Player rate:\(queuePlayer.rate)")
        }
    }
    
    ////
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(queuePlayer.currentTime())
        }
        set {
            //print("newValue:\(newValue)")
            let newTime = CMTimeMakeWithSeconds(newValue, Int32(frameRate))
            queuePlayer.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { (Bool) in
                //print("1---newValue:\(newValue)")
            })
        }
    }
    
    ////
    var duration: Double {
        guard let currentItem = queuePlayer.currentItem else { return 0.0 }
        
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
        let frame = 1.0/frameRate
        // Make sure we don't have a strong reference cycle by only capturing self as weak.
        let interval        = CMTimeMakeWithSeconds(Float64(frame), Int32(NSEC_PER_SEC))
        timeObserverToken   = queuePlayer.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
            let timeElapsed  = Double(CMTimeGetSeconds((self.currentItem?.currentTime())!))
             print("timeElapsed:\(timeElapsed)")
            self.delegate!.playerTimeUpdate(time:timeElapsed)
        }
    }
    

    public func showWaterMark() {
        
        print("Subviews Count:\(mediaPlayer.contentOverlayView?.subviews.count)\n Subviews:\(mediaPlayer.contentOverlayView?.subviews)")
        if mediaPlayer.contentOverlayView?.subviews.count == 0 {
            let label   = UILabel()
            label.text  = "SWift Player"
            label.frame =  CGRect.init(x: 200, y: 100, width: 200, height: 100)
            label.textColor = UIColor.white
            label.sizeToFit()
            mediaPlayer.contentOverlayView?.addSubview(label)
         }
    }

    public func configureAirplay() {
        print("configureAirplay...")
        mediaPlayer.showsPlaybackControls = false
       mediaPlayer.player?.allowsExternalPlayback = false
       mediaPlayer.player?.usesExternalPlaybackWhileExternalScreenIsActive = false
        queuePlayer.allowsExternalPlayback = false
        queuePlayer.usesExternalPlaybackWhileExternalScreenIsActive = false
//        let volumeView = MPVolumeView()
//        volumeView.showsVolumeSlider = false
//        volumeView.sizeToFit()
//        mediaPlayer.view.addSubview(volumeView)
    }
    
    private func cleanUpPlayerPeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            queuePlayer.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func addObservers() {
        // Register as an observer of the player item's status property
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem.status),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        
        
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem.duration),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem.playbackLikelyToKeepUp),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem.playbackBufferEmpty),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem.loadedTimeRanges),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)

        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(rate),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        
        queuePlayer.addObserver(self,
                    forKeyPath: #keyPath(currentItem),
                    options: [.old, .new],
                    context: &playerViewControllerKVOContext)
        
        //
        
    }
    
    func removeObservers() {
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem.duration), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem.status), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem.playbackLikelyToKeepUp), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem.playbackBufferEmpty), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem.loadedTimeRanges), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(rate), context: &playerViewControllerKVOContext)
        queuePlayer.removeObserver(self, forKeyPath: #keyPath(currentItem), context: &playerViewControllerKVOContext)
     
        cleanUpPlayerPeriodicTimeObserver()
        
    }
    
    func prepareToPlay() {
        frameRate = getAssetFrameRate()
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: currentItem)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name:NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        //addObservers()
        showWaterMark()
        //setUpWaterMarkLayer()
        setupPlayerPeriodicTimeObserver()
    }
    
    func cleanUp() {
        pause()
        rate        = 0.0
        currentTime = 0.0
        removeObservers()
        NotificationCenter.default.removeObserver(self)
        queuePlayer.removeAllItems()
        urlAsset    = nil
        currentItem = nil
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        if (queuePlayer.items().isEmpty) == false && (duration != 0.0) {
            print("PlayerDidFinishPlaying current item...")
            self.delegate!.playerFrameRateChanged(frameRate: 0)
            self.delegate!.playerTimeUpdate(time:Double(0.0))
            cleanUp()
            initPlayer(urlString: "")
        }
    }
    
   func applicationWillEnterForeground(note: NSNotification) {
    print("applicationWillEnterForeground..SubviewsCount:%@\(mediaPlayer.contentOverlayView?.subviews.count),subviews:\(mediaPlayer.contentOverlayView?.subviews)")
   
    }
    
    func getAssetFrameRate() -> Float {
        frameRate = 0.0
        for track in (currentItem?.tracks)! {
            
            if(track.assetTrack.mediaType == AVMediaTypeVideo) {
                frameRate = track.currentVideoFrameRate
                break
            }
        }
        
        if (frameRate == 0) {
            
            if (currentItem?.asset != nil) {
                if let videoTrack = currentItem?.asset.tracks(withMediaType: AVMediaTypeVideo).last {
                    frameRate = videoTrack.nominalFrameRate
                }
            }
        }
        
        if (frameRate == 0) {
            frameRate = 25.0
        }
        return frameRate
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
            DispatchQueue.main.async {
                /*
                 `self.asset` has already changed! No point continuing because
                 another `newAsset` will come along in a moment.
                 */
                // guard newAsset == self.urlAsset else { return }
                
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
                self.urlAsset = newAsset
                self.currentItem = AVPlayerItem(asset: newAsset, automaticallyLoadedAssetKeys:self.assetKeysRequiredToPlay)
                //self.prepareToPlay()
                //self.play()
                
                self.currentItem?.seek(to: kCMTimeZero)
            }
        }
    }
    
    // MARK: - Error Handling
    
    func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        NSLog("Error occured with message: \(message), error: \(error).")
    }
    
    //****************************************************
    // MARK: - Public methods
    //****************************************************
    
    
    // MARK: - Player related methods
    
    public func initPlayer(urlString: String) {
        
       // var urlString = urlString
        ///////////Demo Urls//////////////////////////////////////
        var urlString = Bundle.main.path(forResource: "trailer_720p", ofType: "mov")!
        //var urlString   = Bundle.main.path(forResource: "ElephantSeals", ofType: "mov")!
        let localURL    = true
        //let localURL    = false
        
        // MARK: - m3u8 urls
        // let urlString = Bundle.main.path(forResource: "bipbopall", ofType: "m3u8")!
        
      //  urlString     = "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
        //  var urlString     = "https://dl.dropboxusercontent.com/u/7303267/website/m3u8/index.m3u8";
      //var urlString     = "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4"
       // urlString = "http://playertest.longtailvideo.com/adaptive/oceans_aes/oceans_aes.m3u8" //(AES encrypted)
        //let urlString = "https://devimages.apple.com.edgekey.net/samplecode/avfoundationMedia/AVFoundationQueuePlayer_HLS2/master.m3u8" //(Reverse playback)
        //let urlString = "http://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8" //(4K)
        //let urlString = "http://vevoplaylist-live.hls.adaptive.level3.net/vevo/ch3/appleman.m3u8" //((LIVE TV)
        //var urlString  = "http://cdn-fms.rbs.com.br/vod/hls_sample1_manifest.m3u8"
        // MARK: - App urls
        // var urlString = "http://nmstream2.clearhub.tv/nmdcMaa/20130713/others/30880d62-2c5b-4487-8ff1-5794d086bea7.mp4"
        //var urlString = "cplp://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"
        
        
        //////////////////////////////////////////
        // configurePlayer()
        // return;
        
        self.delegate.buffering()
        isPlayerInitilaized = false
       /* var urlStr          = urlString as NSString
        
        if (urlStr.range(of:".m3u8").location != NSNotFound && urlStr.range(of:"isml").location == NSNotFound){
            urlStr = urlString.replacingOccurrences(of:"http", with:CUSTOM_SCHEME) as NSString
        }
        urlString   = urlStr as String*/
        var url     = URL.init(string: urlString)!
        if (localURL) {
            url =  URL(fileURLWithPath: urlString)
        }
        print("Streming URL:",urlString)
        
        let headers : [String: String] = ["User-Agent": "iPad"]
        
        queuePlayer = AVQueuePlayer()
        mediaPlayer.player = queuePlayer
        configureAirplay()
        addObservers()
        
        let urlAsset    = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey":headers])
        urlAsset.resourceLoader.setDelegate(self, queue:DispatchQueue.main)
        //let playerItem = AVPlayerItem(asset: urlAsset)
        // mediaPlayer.player = AVPlayer(playerItem: playerItem)
        asynchronouslyLoadURLAsset(urlAsset)
    }
    
  //  var waterMarklayer: CALayer

    
    func setUpWaterMarkLayer() {
        /*var waterMarklayer: CALayer = CALayer()
        waterMarklayer.backgroundColor = UIColor.blue.cgColor
        waterMarklayer.borderWidth = 100.0
        waterMarklayer.borderColor = UIColor.red.cgColor
        waterMarklayer.shadowOpacity = 0.7
        waterMarklayer.shadowRadius = 10.0*/
        
        let titleLayer = CATextLayer()
        titleLayer.backgroundColor = UIColor.clear.cgColor
        titleLayer.string = "Watermark Layer"
       
        titleLayer.frame = CGRect.init(x: 200, y: 100, width: mediaPlayer.videoBounds.width/3, height: mediaPlayer.videoBounds.height / 6)
        titleLayer.fontSize = 28
        titleLayer.shadowOpacity = 0.5
        
        mediaPlayer.view.layer.addSublayer(titleLayer)

        // create text Layer
       /* CATextLayer* titleLayer = [CATextLayer layer];
        titleLayer.backgroundColor = [UIColor clearColor].CGColor;
        titleLayer.string = @"Dummy text";
        titleLayer.font = CFBridgingRetain(@"Helvetica");
        titleLayer.fontSize = 28;
        titleLayer.shadowOpacity = 0.5;
        titleLayer.alignmentMode = kCAAlignmentCenter;
        titleLayer.frame = CGRectMake(0, 50, videoSize.width, videoSize.height / 6);
        [parentLayer addSublayer:titleLayer];*/
        
    }
    
    func configurePlayer() {
        // if I change m3u8 to different file extension, it's working good
        let url = NSURL(string: "cplp://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")
        
        let asset = AVURLAsset(url: url! as URL, options: nil)
        asset.resourceLoader.setDelegate(self, queue:DispatchQueue.main)
        
        let playerItem = AVPlayerItem(asset: asset)
        mediaPlayer.player = AVPlayer(playerItem: playerItem)
        mediaPlayer.player?.play()
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
        
        if keyPath == #keyPath(currentItem.status) {
            let newStatus: AVPlayerItemStatus
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
            }
            else {
                newStatus = .unknown
            }
            
            if newStatus == .failed {
                self.handleErrorWithMessage(queuePlayer.currentItem?.error?.localizedDescription)
                
            }
            else if newStatus == .readyToPlay {
                
                if let asset = queuePlayer.currentItem?.asset {
                    
                    /*
                     First test whether the values of `assetKeysRequiredToPlay` we need
                     have been successfully loaded.
                     */
                    for key in assetKeysRequiredToPlay {
                        var error: NSError?
                        if asset.statusOfValue(forKey: key, error: &error) == .failed {
                            self.handleErrorWithMessage(queuePlayer.currentItem?.error?.localizedDescription)
                            return
                        }
                    }
                    
                    if !asset.isPlayable || asset.hasProtectedContent {
                        // We can't play this asset.
                        self.handleErrorWithMessage(queuePlayer.currentItem?.error?.localizedDescription)
                        return
                    }
                    
                    /*
                     The player item is ready to play,
                     */
                    self.isPlayerInitilaized = true
                    self.delegate!.playerReadyToPlay()
                    print("canPlayReverse:\(queuePlayer.currentItem?.canPlayReverse)")
                }
            }
        } else if keyPath == #keyPath(currentItem.duration) {
            
        }
        else if keyPath == #keyPath(rate) {
            // Update playPauseButton type.
            let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
            self.delegate!.playerFrameRateChanged(frameRate: newRate)
        }
        else if keyPath == #keyPath(currentItem.playbackLikelyToKeepUp) {
            self.delegate!.bufferingFinsihed()
            if (isAutoPlay) {
                self.rate = self.previousRate
            }
        }
        else if keyPath == #keyPath(currentItem.playbackBufferEmpty) {
            self.delegate!.buffering()
        }
        else if keyPath == #keyPath(currentItem.loadedTimeRanges) {
            
            if let timeRanges = change?[NSKeyValueChangeKey.newKey] as? [AnyObject] {
                // let timeRanges = change?[NSKeyValueChangeKey.newKey] as! [AnyObject]
                if (timeRanges.count > 0) {
                    let timerange:CMTimeRange   = timeRanges[0].timeRangeValue
                    let smartValue: CGFloat     = CGFloat(CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration)))
                    let duration: CGFloat       = CGFloat(CMTimeGetSeconds(self.queuePlayer.currentTime()))
                    
                    if ((smartValue - duration > 5.0 || (smartValue == duration))) {
                        self.delegate!.bufferingFinsihed()
                        if (isAutoPlay) {
                            self.rate = self.previousRate
                        }
                    }
                }
                
            }
            
        }
        else if keyPath == #keyPath(currentItem) {
            //guard let player = queuePlayer else { return }
            
            if queuePlayer.rate == -1.0 {
                return
            }
            
            if queuePlayer.items().isEmpty {
                print("Play queue emptied out due to bad player item. End looping")
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
                    queuePlayer.insert(itemRemoved, after: nil)
                    addObservers()
                }
            }
        }
            
        else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    public func playPause() {
        isAutoPlay = false
        if (isPlaying) {
            pause()
        } else {
            play()
        }
    }
    
    public func play() {
        queuePlayer.play()
    }
    
    public func pause() {
        queuePlayer.pause()
    }
    
    // TODO: For |reversePlayback| and |fastForwardPlayback| put check canPlayFastForward, canPlaySlowForward, canPlayReverse etc... and make a single method
    public func playReverse() {
        // Rewind no faster than -4.0.
        var playerRate = max(rate - 1, -4.0)
        if (playerRate == 0) {
            playerRate = -1.0
        }
        playFromRate(playerRate: playerRate)
    }
    
    public func playForward() {
        //Fast forward no faster than 4.0.
        var playerRate = min(rate + 1.0, 4.0)
        if (playerRate == 0) {
            playerRate = 1.0
        }
        playFromRate(playerRate: playerRate)
    }
    
    public func playFromRate(playerRate: Float) {
        isAutoPlay = true
        if rate != playerRate {
            rate = playerRate
        }
    }
    
    
    /*
     * |numberOfFrame| +ve value means move forward and -ve backwoard
     */
    public func stepFrames(byCount numberOfFrame:Int) {
        isAutoPlay = false
        self.pause()
        currentItem?.cancelPendingSeeks()
        let secondsFromFrame    = Float(numberOfFrame)/frameRate
       // self.currentTime        += Double(secondsFromFrame)
        currentItem?.step(byCount: numberOfFrame) //Its working for mp4 and local assets
    }
    
    
    public func stepSeconds(byCount numberOfSecond:Int64) {
        isAutoPlay = false
        self.pause()
        currentItem?.cancelPendingSeeks()
        self.currentTime += Double(numberOfSecond)
    }
    
   
    public func getTimeCodeFromSeonds(time: Float) -> String {
        
        let sec             = Int(time) % 60
        let min             = (Int(time)/60) % 60
        let hours           = (Int(time)/3600) % 60
        let currentTime     = CMTimeMakeWithSeconds(Float64(time), Int32(frameRate))
        let currentTimeF    = CMTimeConvertScale(currentTime, Int32(frameRate), CMTimeRoundingMethod.default)
        let frame           = fmodf(Float(currentTimeF.value), Float(frameRate))
        return String(format: "%02d:%02d:%02d:%02d", hours, min, sec, Int(frame))
    }
    
<<<<<<< HEAD
    public func getAudioTracks()-> [AudioTrack] {
        
        var audioTracks = [AudioTrack]()
        let audio: AVMediaSelectionGroup = (urlAsset?.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicAudible))!
        
        for index in 1...audio.options.count {
            let option: AVMediaSelectionOption = audio.options[index]
            var displayName = Utility.getLanguageName(fromLanguageCode: option.displayName)
            
            if(displayName?.caseInsensitiveCompare("Track") == ComparisonResult.orderedSame) {
                displayName = "Track\(index+1)"
            }
            
            if index == 0 {
                curAudioTrack = displayName!
            }
            
            let track = AudioTrack ()
            track.displayName = displayName!
            track.isAssetTrack = false
            audioTracks.append(track)
        }
        
        if(!audioTracks.isEmpty) {
            availableAudioTracks = audioTracks
            return availableAudioTracks
        }
        
        for index in 1...(urlAsset?.tracks(withMediaType: AVMediaTypeAudio))!.count {
            let option = urlAsset?.tracks(withMediaType: AVMediaTypeAudio)[index]
            var displayName = Utility.getLanguageName(fromLanguageCode: option?.languageCode)
            
            if(displayName?.caseInsensitiveCompare("Track") == ComparisonResult.orderedSame) {
                displayName = "Track\(index+1)"
            }
            
            if index == 0 {
                curAudioTrack = displayName!
            }
            
            let track = AudioTrack ()
            track.displayName = displayName!
            track.isAssetTrack = true
            audioTracks.append(track)
        }
        
        if(!audioTracks.isEmpty) {
            availableAudioTracks = audioTracks
        }
        return audioTracks
=======
    public func getPlayerView ()-> UIView {
        return mediaPlayer.view
>>>>>>> 2a42c209ef0343d2e4287f4069c16361375f8b26
    }
    
    //****************************************************
    // MARK: - AVAssetResourceLoaderDelegate methods
    //****************************************************
    
    // FPS Key Fetch for Persistent Keys
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool
    {
        let scheme = (loadingRequest.request.url?.scheme)! as NSString
        if ((scheme.range(of: CUSTOM_SCHEME).location != NSNotFound))
        {
            let customUrl:NSString? = loadingRequest.request.url?.absoluteString as NSString?
            let urlString = customUrl?.replacingOccurrences(of: CUSTOM_SCHEME, with: "http") as NSString?
            let playlistUrl: NSString? = (NSURL(string: urlString as! String))?.absoluteString as NSString?
            print("PlaylistUrl:\(playlistUrl)")
            
            NetworkManager().startAsyncDownload(playlistUrl as String!, progress: { (CGFloat) in
                
                }, finished: { (response, errorCode) in
                    // if (errorCode == TRACE_CODE_SUCCESS)
                    if (errorCode == 0)
                    {
                        if (playlistUrl?.range(of: ".ckf").location != NSNotFound) {
                            print("Assest Loader Called........")
                            
//                            let strKey = CMServicesUtilities.getStreamDecryptionKey()
//                            let responseData = response as! NSData
//                            let decryptedKey: NSData = responseData.decryptData(withKey: strKey, mode: true) as NSData
//                            loadingRequest.dataRequest?.respond(with: decryptedKey as Data)
//                            loadingRequest.finishLoading()
                        }
                        else
                        {
                            let urlComponents:NSURLComponents = NSURLComponents(url: URL.init(string: playlistUrl as! String)!, resolvingAgainstBaseURL: false)!
                            
                            urlComponents.query = nil
                            var baseURL = urlComponents.url?.deletingLastPathComponent().absoluteString
                            let m3u8Str =  NSString(data: response as! Data, encoding: String.Encoding.utf8.rawValue)!
                            if (m3u8Str.range(of: ".m3u8").location != NSNotFound)
                            {
                                let subReplace = "(\"[a-z0-9/:=~._-]*(\\.m3u8))"
                                // var error:NSError? = nil
                                do
                                {
                                    
                                    let regex: NSRegularExpression = try NSRegularExpression(pattern: subReplace, options:NSRegularExpression.Options.caseInsensitive)
                                    regex.replaceMatches(in: m3u8Str as! NSMutableString, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, m3u8Str.length), withTemplate:"\"\(baseURL)^$1^\"")
                                    
                                    m3u8Str.replacingOccurrences(of:"^\"", with:"")
                                   // CMCache.setObject(m3u8Str.data(using: String.Encoding.utf8.rawValue), forKey: playlistUrl?.md5(), withNewPath: "cache_m3u8")
                                    
                                }
                                catch {
                                    print("problem in REG X")
                                }
                            }
                            else
                            {
                                let tsReplace = "([a-z0-9/:~._-]*(\\.ts))"
                                
                                if (m3u8Str.range(of: "http").location == NSNotFound)
                                {
                                    do
                                    {
                                        let regex: NSRegularExpression = try NSRegularExpression(pattern: tsReplace, options:NSRegularExpression.Options.caseInsensitive)
                                        regex.replaceMatches(in: m3u8Str as! NSMutableString, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, m3u8Str.length), withTemplate:"\(baseURL)$1")
                                    }
                                    catch {
                                        print("problem in Segments")
                                    }
                                    
                                    if (m3u8Str.range(of:"key").location == NSNotFound)
                                    {
                                        let ckfReplace = "([a-z0-9/:~._-]*\\.ckf)"
                                        urlComponents.scheme = urlComponents.scheme?.replacingOccurrences(of: "http", with: self.CUSTOM_SCHEME)
                                        do
                                        {
                                            let regX = try NSRegularExpression(pattern: ckfReplace, options:NSRegularExpression.Options.caseInsensitive)
                                            
                                            baseURL = urlComponents.url?.deletingLastPathComponent().absoluteString
                                            regX.replaceMatches(in: m3u8Str as! NSMutableString, options: NSRegularExpression.MatchingOptions.init(rawValue: 0), range: NSMakeRange(0, m3u8Str.length), withTemplate:"\(baseURL)$1")
                                        }
                                        catch {
                                            print("problem in Segments")
                                        }
                                    }
                                    else {
                                        m3u8Str.replacingOccurrences(of:"key", with:self.CUSTOM_SCHEME)
                                    }
                                }
                                else {
                                    m3u8Str.replacingOccurrences(of:"key", with:self.CUSTOM_SCHEME)
                                }
                            }
                            print("m3u8Str....\(m3u8Str)")
                            //For Live Asset Check for ENDLIST flag
                            //
                            //                                                            if ([self.delegate respondsToSelector:@selector(isLiveAssetGrowingProxy:)])
                            //                                                            {
                            //                                                                if([m3u8Str rangeOfString:@"EXT-X-ENDLIST"].location != NSNotFound) {
                            //                                                                    [_delegate isLiveAssetGrowingProxy:NO];
                            //                                                                }
                            //                                                            }
                            let data = m3u8Str.data(using: String.Encoding.utf8.rawValue)
                            loadingRequest.dataRequest?.respond(with: data!)
                            loadingRequest.finishLoading()
                        }
                    }
                    else {
                        print("error in key response\(response)");
                    }
            })
            return true
        }
        return false
    }
    
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForResponseTo authenticationChallenge: URLAuthenticationChallenge) -> Bool {
        let protectionSpace = authenticationChallenge.protectionSpace
        
        if protectionSpace.authenticationMethod ==  NSURLAuthenticationMethodServerTrust {
            
            authenticationChallenge.sender?.use(URLCredential.init(trust: authenticationChallenge.protectionSpace.serverTrust!), for: authenticationChallenge)
            authenticationChallenge.sender?.continueWithoutCredential(for: authenticationChallenge)
            
        }
        return true
    }
}
