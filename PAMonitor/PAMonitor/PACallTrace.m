//
//  PACallTrace.m
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import "PACallTrace.h"
#import "PACallLib.h"
#import "PACallTraceTimeCostModel.h"
#import "PALagDB.h"
#import "PACallTraceCore.h"

@implementation PACallTrace

#pragma mark - Trace
#pragma mark - OC Interface
+ (void)start {
    paCallTraceStart();
}
+ (void)startWithMaxDepth:(int)depth {
    paCallConfigMaxDepth(depth);
    [PACallTrace start];
}
+ (void)startWithMinCost:(double)ms {
    paCallConfigMinTime(ms * 1000);
    [PACallTrace start];
}
+ (void)startWithMaxDepth:(int)depth minCost:(double)ms {
    paCallConfigMaxDepth(depth);
    paCallConfigMinTime(ms * 1000);
    [PACallTrace start];
}
+ (void)stop {
    paCallTraceStop();
}
+ (void)save {
    NSMutableString *mStr = [NSMutableString new];
    NSArray<PACallTraceTimeCostModel *> *arr = [self loadRecords];
    for (PACallTraceTimeCostModel *model in arr) {
        //记录方法路径
        model.path = [NSString stringWithFormat:@"[%@ %@]",model.className,model.methodName];
        [self appendRecord:model to:mStr];
    }
    //    NSLog(@"%@",mStr);
}
+ (void)stopSaveAndClean {
    [PACallTrace stop];
    [PACallTrace save];
    paClearCallRecords();
}
+ (void)appendRecord:(PACallTraceTimeCostModel *)cost to:(NSMutableString *)mStr {
    //    [mStr appendFormat:@"%@\n path%@\n",[cost des],cost.path];
    if (cost.subCosts.count < 1) {
        cost.lastCall = YES;
        //记录到数据库中
        [[PALagDB sharedInstance] addWithClsCallModel:cost];
    } else {
        for (PACallTraceTimeCostModel *model in cost.subCosts) {
            if ([model.className isEqualToString:NSStringFromClass([PACallTrace class])]) {
                break;
            }
            //记录方法的子方法的路径
            model.path = [NSString stringWithFormat:@"%@ - [%@ %@]",cost.path,model.className,model.methodName];
            [self appendRecord:model to:mStr];
        }
    }
    
}
+ (NSArray<PACallTraceTimeCostModel *>*)loadRecords {
    NSMutableArray<PACallTraceTimeCostModel *> *arr = [NSMutableArray new];
    int num = 0;
    paCallRecord *records = paGetCallRecords(&num);
    for (int i = 0; i < num; i++) {
        paCallRecord *rd = &records[i];
        PACallTraceTimeCostModel *model = [PACallTraceTimeCostModel new];
        model.className = NSStringFromClass(rd->cls);
        model.methodName = NSStringFromSelector(rd->sel);
        model.isClassMethod = class_isMetaClass(rd->cls);
        model.timeCost = (double)rd->time / 1000000.0;
        model.callDepth = rd->depth;
        [arr addObject:model];
    }
    NSUInteger count = arr.count;
    for (NSUInteger i = 0; i < count; i++) {
        PACallTraceTimeCostModel *model = arr[i];
        if (model.callDepth > 0) {
            [arr removeObjectAtIndex:i];
            //Todo:不需要循环，直接设置下一个，然后判断好边界就行
            for (NSUInteger j = i; j < count - 1; j++) {
                //下一个深度小的话就开始将后面的递归的往 sub array 里添加
                if (arr[j].callDepth + 1 == model.callDepth) {
                    NSMutableArray *sub = (NSMutableArray *)arr[j].subCosts;
                    if (!sub) {
                        sub = [NSMutableArray new];
                        arr[j].subCosts = sub;
                    }
                    [sub insertObject:model atIndex:0];
                }
            }
            i--;
            count--;
        }
    }
    return arr;
}
@end
