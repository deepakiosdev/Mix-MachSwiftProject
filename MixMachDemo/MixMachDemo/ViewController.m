//
//  ViewController.m
//  MixMachDemo
//
//  Created by Deepak on 24/09/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import "ViewController.h"
#import "MixMachDemo-Swift.h"
<<<<<<< HEAD
#import <AVFoundation/AVFoundation.h>
=======
#import <AVKit/AVKit.h>

>>>>>>> 2a42c209ef0343d2e4287f4069c16361375f8b26

@class PlayerViewController;

@interface ViewController () <PlayerViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UISlider *seekBar;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTime;
@property (weak, nonatomic) IBOutlet UILabel *duration;
<<<<<<< HEAD

@property (nonatomic, strong) IBOutlet UIView *playerContainerView;
@property (nonatomic, strong) IBOutlet UIView *playerContainerSuperView;
@property (nonatomic, strong) PlayerViewController *playerVC;
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (nonatomic, strong) UIWindow                      *externalWindow;
@property (nonatomic, strong) UIScreen                      *externalScreen;
=======
@property (weak, nonatomic) IBOutlet UIView *playerContainerSuperView;
@property (weak, nonatomic) IBOutlet UIView *playerContainerView;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic, strong) PlayerViewController *playerVC;
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loadingIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *airPlayThumbnail;

@property (nonatomic, strong)   UIWindow                     *externalWindow;
@property (nonatomic, strong)   UIScreen                     *externalScreen;

>>>>>>> 2a42c209ef0343d2e4287f4069c16361375f8b26
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

    }

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


-(void)viewWillDisappear:(BOOL)animated
{
    [self externalScreenDidDisconnect:nil];
    [super viewWillDisappear: animated];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenDidDisconnectNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIScreenModeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
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
    // self.connectedLabel.hidden = NO;
    if(!_externalWindow) {
        _externalWindow = [[UIWindow alloc] initWithFrame:[self.externalScreen bounds]];
    }
    [_externalWindow setHidden:NO];
    
    [[_externalWindow layer] setContentsGravity:AVLayerVideoGravityResizeAspect];
    [_externalWindow setScreen:self.externalScreen];
    [[_externalWindow screen] setOverscanCompensation:UIScreenOverscanCompensationScale];
    
    
    //[_playerContainerView setFrame:[_externalWindow bounds]];
    // [_externalWindow addSubview:_playerVC.view];
    
    [self getAVplayerLayerFromView:_playerVC.media view];
    
    UIView *view            = [[UIView alloc] init];
    _playerLayer.frame      = [_externalWindow bounds];
    [_playerLayer setContentsGravity:AVLayerVideoGravityResizeAspectFill];
    [view.layer addSublayer:_playerLayer];
    view.frame  = [_externalWindow bounds];
    _waterMarkLbl.hidden = YES;
    UILabel *waterMarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(500, 150, 200, 70)];
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
   // _waterMarkLbl.hidden    = NO;
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
    
}

-(void)exteralScreenModeDidChange:(NSNotification*)notification
{
}

- (void)getAVplayerLayerFromView:(UIView *)view {
    // Get the subviews of the view
    NSArray *subviews = [view subviews];
    // Return if there are no subviews
    if ([subviews count] == 0) return; // COUNT CHECK LINE
    
    for (UIView *subview in subviews) {
        //[subview isKindOfClass:[UIView class]] //_AVPlayerLayerView//AVPlayerLayer
        NSLog(@"++++++++view:%@",subview);
        if ([subview.layer isKindOfClass:[AVPlayerLayer class]])
        {
            _playerLayer = (AVPlayerLayer *)subview.layer;
            return;
        }
        // List the subviews of subview
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


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


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

- (void)listSubviewsOfView:(UIView *)view {
    
    // Get the subviews of the view
    NSArray *subviews = [view subviews];
    
    // Return if there are no subviews
    if ([subviews count] == 0) return; // COUNT CHECK LINE
    
    for (UIView *subview in subviews) {
        
        // Do what you want to do with the subview
        NSLog(@"++++++++view:%@",subview);
        if ([subview isKindOfClass:[UILabel class]] || [subview isKindOfClass:[UIView class]] || [subview isKindOfClass:[UIImageView class]] || [subview isKindOfClass:[UIButton class]] || [subview isKindOfClass:[UIView class]] || [subview isKindOfClass:[UIView class]]) {
            subview.hidden = YES;
        }
        
        // List the subviews of subview
        [self listSubviewsOfView:subview];
    }
}

-(void)configureExternalScreen:(UIScreen *)externalScreen
{
    NSLog(@"configureExternalScreen....");
    
    self.externalScreen = externalScreen;
    
//    for (UIWindow *window in [UIApplication sharedApplication].windows) {
//        NSLog(@"============window:%@",window);
//        for (UIView *view in window.subviews) {
//            [self listSubviewsOfView:view];
//        }
//    }
    
    for (UIScreen *aScreen in UIScreen.screens)
    {
        NSLog(@"----------Screen:%@",aScreen);
    }
    
    //UIWindow *window = [[UIApplication sharedApplication].windows lastObject];
    
    //_airPlayThumbnail.hidden = NO;
    // NSLog(@"1......._externalWindow:%@",_externalWindow);
    if(!_externalWindow) {
        _externalWindow = [[UIWindow alloc] initWithFrame:[self.externalScreen bounds]];
    }
    //_externalWindow = window;
    
    [_externalWindow setHidden:NO];
    
    [[_externalWindow layer] setContentsGravity:kCAGravityResizeAspect];
    [_externalWindow setScreen:self.externalScreen];
    [[_externalWindow screen] setOverscanCompensation:UIScreenOverscanCompensationScale];
    [_externalWindow makeKeyAndVisible];


    [_playerContainerView setFrame:[_externalWindow bounds]];
 
    
    //[self listSubviewsOfView:_playerContainerView];

    [_externalWindow addSubview:_playerContainerView];
    
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
    
    [self checkOverlayCountsAfterDelay];

    //NSLog(@"2.......screen:%@",_externalWindow.screen);
    // NSLog(@"2......._externalWindow:%@",_externalWindow);
    //NSLog(@"subviews.count:%lu \n_externalWindow.subviews:%@",(unsigned long)_externalWindow.subviews.count, _externalWindow.subviews);
    //  NSLog(@"keyWindow:%@",[[UIApplication sharedApplication] keyWindow]);
    // NSLog(@"windows:%@",[[UIApplication sharedApplication] windows]);
    
}

-(void)externalScreenDidConnect:(NSNotification*)notification
{
    [self checkOverlayCountsAfterDelay];
    UIScreen *externalScreen = [notification object];
    [self configureExternalScreen:externalScreen];
}

- (void)checkOverlayCountsAfterDelay {
    [self performSelector:@selector(checkOverlayCounts) withObject:nil afterDelay:2.0];
}

- (void)checkOverlayCounts {
    [_playerVC showWaterMark];

}
-(void)externalScreenDidDisconnect:(NSNotification*)notification
{
    NSLog(@"externalScreenDidDisconnect....");
    //_airPlayThumbnail.hidden = YES;
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
    
}

-(void)exteralScreenModeDidChange:(NSNotification*)notification
{
}

@end
