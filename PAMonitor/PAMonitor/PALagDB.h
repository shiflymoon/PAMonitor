//
//  PALagDB.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PACallStackModel.h"
#import "PACallTraceTimeCostModel.h"

#define PATH_OF_APP_HOME    NSHomeDirectory()
#define PATH_OF_TEMP        NSTemporaryDirectory()
#define PATH_OF_DOCUMENT    [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]


NS_ASSUME_NONNULL_BEGIN

@interface PALagDB : NSObject

+ (instancetype)sharedInstance;
/*------------卡顿和CPU超标堆栈---------------*/
- (void)increaseWithStackModel:(PACallStackModel *)model;
- (NSArray<PACallStackModel *> *)selectStackWithPage:(NSUInteger)page;
- (void)clearStackData;
/*------------ClsCall方法调用频次-------------*/
//添加记录s
- (void)addWithClsCallModel:(PACallTraceTimeCostModel *)model;
//分页查询
- (NSArray<PACallTraceTimeCostModel *> *)selectClsCallWithPage:(NSUInteger)page;
//清除数据
- (void)clearClsCallData;
@end

NS_ASSUME_NONNULL_END
