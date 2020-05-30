//
//  PACallStackModel.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PACallStackModel : NSObject

@property (nonatomic, copy) NSString *stackStr;       //完整堆栈信息
@property (nonatomic) BOOL isStuck;                   //是否被卡住
@property (nonatomic, assign) NSTimeInterval dateString;   //可展示信息

@end

NS_ASSUME_NONNULL_END
