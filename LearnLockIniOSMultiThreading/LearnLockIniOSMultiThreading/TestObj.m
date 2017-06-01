//
//  TestObj.m
//  LearnLock
//
//  Created by yiqiwang(王一棋) on 2017/5/31.
//  Copyright © 2017年 melody5417. All rights reserved.
//

#import "TestObj.h"

@implementation TestObj

- (instancetype)init {
    if (self = [super init]) {
        _property1 = 0;
        self.property2 = 0;
    }
    return self;
}

- (void)method1 {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)method2 {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
