//
//  TestObj.h
//  LearnLock
//
//  Created by yiqiwang(王一棋) on 2017/5/31.
//  Copyright © 2017年 melody5417. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TestObj : NSObject

@property (nonatomic, assign) NSUInteger property1;
@property (atomic, assign) NSUInteger property2;

- (void)method1;
- (void)method2;

@end
