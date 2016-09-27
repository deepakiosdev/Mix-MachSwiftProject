//
//  ViewController.m
//  MixMachDemo
//
//  Created by Deepak on 24/09/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import "ViewController.h"
#import "MixMachDemo-Swift.h"

@class PlayerViewController;

@interface ViewController () <PlayerViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UISlider *seekBar;
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTime;
@property (weak, nonatomic) IBOutlet UILabel *duration;

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic, strong) PlayerViewController *playerVC;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _seekBar.value              = 0.0;
    _playPauseButton.enabled    = NO;
    _currentTime.text           = @"00:00:00:00";
    _duration.text              = @"00:00:00:00";
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

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

//****************************************************
// MARK: - PlayerViewControllerDelegate Methods
//****************************************************
- (void)playerTimeUpdateWithTime:(double)time {
    self.seekBar.value  = time;
    _currentTime.text   = [_playerVC getTimeCodeFromSeondsWithTime:time];
}

- (void)playerReadyToPlay {
    self.seekBar.maximumValue   = _playerVC.duration;
    _playPauseButton.enabled    = YES;
    _duration.text              = [_playerVC getTimeCodeFromSeondsWithTime:_playerVC.duration];
}

- (void)playerFrameRateChangedWithFrameRate:(float)frameRate {
    
    if (frameRate == 0.0) {
        _playPauseButton.selected = NO;
    } else {
        _playPauseButton.selected = YES;

    }
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
    [_playerVC playeForward];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
