//
//  PACallTraceTimeCostModel.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PACallTraceTimeCostModel : NSObject

@property (nonatomic, strong) NSString *className;       //类名
@property (nonatomic, strong) NSString *methodName;      //方法名
@property (nonatomic, assign) BOOL isClassMethod;        //是否是类方法
@property (nonatomic, assign) NSTimeInterval timeCost;   //时间消耗
@property (nonatomic, assign) NSUInteger callDepth;      //Call 层级
@property (nonatomic, copy) NSString *path;              //路径
@property (nonatomic, assign) BOOL lastCall;             //是否是最后一个 Call
@property (nonatomic, assign) NSUInteger frequency;      //访问频次
@property (nonatomic, strong) NSArray <PACallTraceTimeCostModel *> *subCosts;

@end

NS_ASSUME_NONNULL_END
