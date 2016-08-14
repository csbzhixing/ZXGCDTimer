//
//  ViewController.m
//  ZXGCDTimer
//
//  Created by csbzhixing on 16/8/14.
//  Copyright © 2016年 csbzhixing. All rights reserved.
//

#import "ViewController.h"
#import "ZXGCDTimer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    static int i = 1;

    static int j = 1;
    [[ZXGCDTimerManager sharedInstance] scheduledDispatchTimerWithName:@"csb"
                                                          timeInterval:1
                                                                 queue:nil
                                                               repeats:YES
                                                            actionType:ZXAbandonPreviousAction
                                                                action:^{
                                                                    NSLog(@"%d", i++);
                                                                }];

    [[ZXGCDTimerManager sharedInstance] scheduledDispatchTimerWithName:@"csb2"
                                                          timeInterval:2
                                                                 queue:nil
                                                               repeats:YES
                                                            actionType:ZXMergePreviousAction
                                                                action:^{
                                                                    NSLog(@"%d", j++ * 10);
                                                                }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
