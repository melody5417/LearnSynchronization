//
//  ViewController.m
//  TestDistributedLock
//
//  Created by yiqiwang(王一棋) on 2017/5/31.
//  Copyright © 2017年 melody5417. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self lockWithDistributedLock];
}

- (void)lockWithDistributedLock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;
        NSDistributedLock *lock = [[NSDistributedLock alloc] initWithPath:[desktopPath stringByAppendingPathComponent:@"testDistributedLock__"]];

        while (![lock tryLock]) {
            NSLog(@"appB waiting");
            sleep(1);
        }

        [lock unlock];
        NSLog(@"appB OK");
    });
}

@end
