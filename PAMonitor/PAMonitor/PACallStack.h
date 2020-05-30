//
//  PACallStack.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PACallLib.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PACallStackType) {
    PACallStackTypeAll,     //全部线程
    PACallStackTypeMain,    //主线程
    PACallStackTypeCurrent  //当前线程
};

@interface PACallStack : NSObject

+ (NSString *)callStackWithType:(PACallStackType)type;

extern NSString *paStackOfThread(thread_t thread);
@end

NS_ASSUME_NONNULL_END
