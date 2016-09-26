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

@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (nonatomic, strong) PlayerViewController *playerVC;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.seekBar.value = 0.0;
    // Do any additional setup after loading the view, typically from a nib.

}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _playPauseButton.enabled = NO;
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
    self.seekBar.value = time;

}

- (void)playerReadyToPlay {
    self.seekBar.maximumValue = _playerVC.duration;
    _playPauseButton.enabled = YES;

}

- (void)playerFrameRateChangedWithFrameRate:(double)frameRate {
    //_playPauseButton.selected = frameRate;
   // [_playerVC playPause];
}


//****************************************************
// MARK: - Action Methods
//****************************************************

- (IBAction)seekBarValueChanged:(id)sender {
}

- (IBAction)playPause:(UIButton *)sender {
    sender.selected = !sender.selected;
    [_playerVC playPause];
}

- (IBAction)next:(id)sender {
}

- (IBAction)repeat:(id)sender {
}

- (IBAction)revsersePlayback:(id)sender {
    [_playerVC reversePlayback];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
