//
//  ViewController.m
//  MixMachDemo
//
//  Created by Deepak on 24/09/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import "ViewController.h"

#import "MixMachDemo-Swift.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "Utility.h"



@class PlayerViewController;

@interface ViewController () <PlayerViewControllerDelegate, AudioTrackDelegate, BitrateListDelegate>

@property (weak, nonatomic) IBOutlet UISlider *seekBar;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTime;
@property (weak, nonatomic) IBOutlet UILabel *duration;

@property (nonatomic, strong) IBOutlet UIView *playerContainerView;
@property (nonatomic, strong) IBOutlet UIView *playerContainerSuperView;
@property (nonatomic, strong) PlayerViewController *playerVC;
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (weak, nonatomic) IBOutlet UILabel *waterMarkLbl;
@property (nonatomic, strong) UIWindow      *externalWindow;
@property (nonatomic, strong) UIScreen      *externalScreen;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) NSArray *audioTracks;
@property (nonatomic, strong) NSArray *bitRates;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _seekBar.value              = 0.0;
    _playPauseButton.enabled    = NO;
    _currentTime.text           = @"00:00:00:00";
    _duration.text              = @"00:00:00:00";
    [_controlsView setUserInteractionEnabled:NO];
}


-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidConnect:) name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidDisconnect:) name:UIScreenDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(exteralScreenModeDidChange:) name:UIScreenModeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidDisconnect:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalScreenDidDisconnect:) name:UIApplicationWillTerminateNotification object:nil];
   
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (_playerVC.isPlayerInitilaized) {
        [self setupExternalScreen];
    }
    
   /* _playerVC = [PlayerViewController new];
    NSString *url = @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
    AVPlayerViewController *playerVC = [self.storyboard instantiateViewControllerWithIdentifier:@"PlayerViewController"];
    _playerVC.mediaPlayer = playerVC;
    [_playerVC initWithUrlWithUrl:url];
    // show the view controller
    [self addChildViewController:_playerVC.mediaPlayer];
    [self.view addSubview:_playerVC.mediaPlayer.view];
    _playerVC.mediaPlayer.view.frame = _containerView.frame;*/
}


-(void)viewWillDisappear:(BOOL)animated
{
    [self externalScreenDidDisconnect:nil];
    [super viewWillDisappear:animated];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenModeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
    if ([segue.identifier isEqualToString:@"PlayerViewController"]) {
       AVPlayerViewController *playerVC = (AVPlayerViewController *)
        segue.destinationViewController;
        
        _playerVC               = [PlayerViewController new];
        _playerVC.delegate      = self;
        _playerVC.mediaPlayer   = playerVC;
        NSString *url           = @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
        [_playerVC initPlayerWithUrlString:url];

    } else if ([segue.identifier isEqualToString:@"AudioTrackListVC"]) {
        
        AudioTrackListVC *audioTrackVC = (AudioTrackListVC *)
        segue.destinationViewController;
        audioTrackVC.audioTracks = _audioTracks;
        audioTrackVC.delegate      = self;
    } else if ([segue.identifier isEqualToString:@"BitrateListVC"]) {
        [_playerVC pause];
        BitrateListVC *bitrateListVC = (BitrateListVC *)
        segue.destinationViewController;
        bitrateListVC.bitRates = _bitRates;
        bitrateListVC.delegate = self;
    }
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - EXternal Display Methods
- (void)setupExternalScreen
{
    // Setup screen mirroring for an existing screen
    NSArray *connectedScreens = [UIScreen screens];
    NSLog(@"connectedScreens count:%lu: ",(unsigned long)connectedScreens.count);
    if ([connectedScreens count] > 1)
    {
        UIScreen *mainScreen = [UIScreen mainScreen];
        for (UIScreen *aScreen in connectedScreens)
        {
            if (aScreen != mainScreen)
            {
                [self configureExternalScreen:aScreen];
                break;
            }
        }
    }
}

-(void)externalScreenDidConnect:(NSNotification*)notification
{
    UIScreen *externalScreen = [notification object];
    [self configureExternalScreen:externalScreen];
}

-(void)configureExternalScreen:(UIScreen *)externalScreen
{
    NSLog(@"configureExternalScreen....");
    
    self.externalScreen = externalScreen;
    _waterMarkLbl.hidden = YES;
    if(!_externalWindow) {
        _externalWindow = [[UIWindow alloc] initWithFrame:[self.externalScreen bounds]];
    }
    [_externalWindow setHidden:NO];
    
    [[_externalWindow layer] setContentsGravity:AVLayerVideoGravityResizeAspect];
    [_externalWindow setScreen:self.externalScreen];
    [[_externalWindow screen] setOverscanCompensation:UIScreenOverscanCompensationScale];
    
    
    //[_playerContainerView setFrame:[_externalWindow bounds]];
    // [_externalWindow addSubview:_playerVC.view];
    
    [self getAVplayerLayerFromView:[_playerVC getPlayerView]];
    
    UIView *view            = [[UIView alloc] init];
    _playerLayer.frame      = [_externalWindow bounds];
    [_playerLayer setContentsGravity:AVLayerVideoGravityResizeAspectFill];
    [view.layer addSublayer:_playerLayer];
    view.frame  = [_externalWindow bounds];

    UILabel *waterMarkLabel = [[UILabel alloc] initWithFrame:_waterMarkLbl.frame];
    waterMarkLabel.text = @"Player Watermark";
    [waterMarkLabel sizeToFit];
    waterMarkLabel.textColor = [UIColor whiteColor];
    [view addSubview:waterMarkLabel];
    [view bringSubviewToFront:waterMarkLabel];
    [_externalWindow addSubview:view];
    
    [_playerContainerView updateConstraintsIfNeeded];
    [_playerContainerView setNeedsLayout];
    [_playerContainerView setTranslatesAutoresizingMaskIntoConstraints:YES];
    for(NSLayoutConstraint *c in _playerContainerSuperView.constraints)
    {
        if(c.firstItem == _playerContainerView || c.secondItem == _playerContainerView) {
            [_playerContainerSuperView removeConstraint:c];
        }
    }
    [_externalWindow makeKeyAndVisible];
}


-(void)externalScreenDidDisconnect:(NSNotification*)notification
{
    NSLog(@"externalScreenDidDisconnect....");
    _waterMarkLbl.hidden = NO;
    //[self.view bringSubviewToFront:_waterMarkLbl];
   // [[self.playerVC getPlayerView] bringSubviewToFront:_waterMarkLbl];
   // [self.playerContainerSuperView bringSubviewToFront:_waterMarkLbl];
   // [self.playerContainerView bringSubviewToFront:_waterMarkLbl];
    [_playerContainerView setFrame:[_playerContainerSuperView bounds]];
    [_playerContainerSuperView addSubview:_playerContainerView];
    
    [_playerContainerView updateConstraintsIfNeeded];
    [_playerContainerView setNeedsLayout];
    [_playerContainerView setTranslatesAutoresizingMaskIntoConstraints:YES];
    
    if(_externalWindow)
    {
        self.externalScreen = nil;
        [_externalWindow setHidden:YES];
        [_externalWindow resignKeyWindow];
    }
    _externalWindow = nil;
    [self.view bringSubviewToFront:_waterMarkLbl];
}

-(void)exteralScreenModeDidChange:(NSNotification*)notification
{
}

- (void)getAVplayerLayerFromView:(UIView *)view {
    // Get the subviews of the view
    NSArray *subviews = [view subviews];
    // Return if there are no subviews
    if ([subviews count] == 0) return;
    
    for (UIView *subview in subviews) {
        NSLog(@"++++++++view:%@",subview);
        if ([subview.layer isKindOfClass:[AVPlayerLayer class]])
        {
            _playerLayer = (AVPlayerLayer *)subview.layer;
            return;
        }
        [self getAVplayerLayerFromView:subview];
    }
}


//****************************************************
// MARK: - PlayerViewControllerDelegate Methods
//****************************************************

- (void)playerTimeUpdateWithTime:(double)time {
    self.seekBar.value  = time;
    _currentTime.text   = [_playerVC getTimeCodeFromSeondsWithTime:time];
}

- (void)playerReadyToPlay {
    NSLog(@"playerReadyToPlay....");
    self.seekBar.maximumValue   = _playerVC.duration;
    _playPauseButton.enabled    = YES;
    _duration.text              = [_playerVC getTimeCodeFromSeondsWithTime:_playerVC.duration];
    [_controlsView setUserInteractionEnabled:YES];
    [_loadingIndicator stopAnimating];
    
    _audioTracks                = [_playerVC getAudioTracks];

    if (!_bitRates) {
        NSString *fileName      = @"test";
        NSString* path          = [[NSBundle mainBundle] pathForResource:fileName ofType:@"m3u8"];
        //Then loading the content into a NSString is even easier.
        NSString *m3u8String    = [NSString stringWithContentsOfFile:path
                                                         encoding:NSUTF8StringEncoding
                                                            error:NULL];
        _bitRates               = [[Utility getBitratesFromM3u8:m3u8String withURL:nil] mutableCopy];
    }
}

- (void)playerFrameRateChangedWithFrameRate:(float)frameRate {
    
    if (frameRate == 0) {
        _playPauseButton.selected = NO;
    } else {
        _playPauseButton.selected = YES;

    }
}

- (void)buffering
{
    NSLog(@"buffering.....");
    [_controlsView setUserInteractionEnabled:NO];
    [_loadingIndicator startAnimating];
    //[_playerVC pause];
}

- (void)bufferingFinsihed
{
    NSLog(@"bufferingFinsihed.....");
    [_controlsView setUserInteractionEnabled:YES];
    [_loadingIndicator stopAnimating];
    //[_playerVC play];
}

//****************************************************
// MARK: - Action Methods
//****************************************************

- (IBAction)seekBarValueChanged:(UISlider *)sender {
    _playerVC.currentTime = sender.value;
}

- (IBAction)playPause:(UIButton *)sender {
    [_playerVC playPause];
    //sender.selected = !sender.selected;
}

- (IBAction)moveToPreviousFrame:(id)sender {
    [_playerVC stepFramesByCount:-1];
}

- (IBAction)moveToNextFrame:(id)sender {
    [_playerVC stepFramesByCount:1];
}

- (IBAction)moveBackwordBySec:(id)sender {
    [_playerVC stepSecondsByCount:-1];
}

- (IBAction)moveForwordBySec:(id)sender {
    [_playerVC stepSecondsByCount:1];
}


- (IBAction)revsersePlayback:(id)sender {
    [_playerVC playReverse];
}

- (IBAction)fastForward:(id)sender {
    [_playerVC playForward];
}

//****************************************************
// MARK: - AudioTrackDelegate Method
//****************************************************

- (void)selectedWithAudioTrack:(AudioTrack *)track {
    [_playerVC switchToSelectedWithAudioTrack:track];
}

//****************************************************
// MARK: - BitrateListDelegate Method
//****************************************************


-(void)selectedWithBitrate:(Bitrate *)bitrate {
    [_playerVC switchToSelectedWithBitRate:bitrate];
}
@end
