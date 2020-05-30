//
//  PACPUMonitor.m
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/19.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import "PACPUMonitor.h"
#import "PACallLib.h"
#import "PALagDB.h"
#import "PACallStackModel.h"
#import "PACallStack.h"
#import "PASuspendResumeThread.h"

@implementation PACPUMonitor

//轮询检查多个线程 cpu 情况
+ (void)updateCPU {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    const task_t thisTask = mach_task_self();
    kern_return_t kr = task_threads(thisTask, &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        return;
    }
    for (int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        thread_basic_info_t threadBaseInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        if (thread_info((thread_act_t)threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount) == KERN_SUCCESS) {
            threadBaseInfo = (thread_basic_info_t)threadInfo;
            if (!(threadBaseInfo->flags & TH_FLAGS_IDLE)) {
                integer_t cpuUsage = threadBaseInfo->cpu_usage / 10;
                if (cpuUsage > CPUMONITORRATE) {
                    //cup 消耗大于设置值时打印和记录堆栈
                    pamc_suspendEnvironment();
                    NSString *reStr = paStackOfThread(threads[i]);
                    pamc_resumeEnvironment();
                    [self recordCPUHighStackInfo:reStr];
                    
                }//end if(cpuUsage >CPUM)
            }//end if(!(threadBaseInfo
        }//end if(thread_info
    }
}


+(void) recordCPUHighStackInfo:(NSString *) stackInfo
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if(![stackInfo containsString:PACallPreExclude()]){
            PACallStackModel *model = [[PACallStackModel alloc] init];
            model.stackStr = stackInfo;
            //记录数据库中
            [[PALagDB sharedInstance] increaseWithStackModel:model] ;
            PALog(@"CPU useage overload thread stack：\n%@",stackInfo);
        }
    });
}

static inline NSString * PACallPreExclude(void){
    NSString * PACallStackStr = NSStringFromClass([PACallStack class]);
    NSString *callStackWithTypeStr = NSStringFromSelector(@selector(callStackWithType:));
    static NSString * excludeStr = @"";
    if(![excludeStr length]){
        assert([PACallStack respondsToSelector:@selector(callStackWithType:)]);
        excludeStr = [NSString stringWithFormat:@"+[%@ %@]",PACallStackStr,callStackWithTypeStr];
    }
    return excludeStr;
}

uint64_t memoryFootprint() {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (result != KERN_SUCCESS)
        return 0;
    return vmInfo.phys_footprint;
}
@end
