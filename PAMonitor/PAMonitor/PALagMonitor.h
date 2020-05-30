//
//  PALagMonitor.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PALagMonitor : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) BOOL isMonitoring;

- (void)beginMonitor; //开始监视卡顿
- (void)endMonitor;   //停止监视卡顿


@end

NS_ASSUME_NONNULL_END
