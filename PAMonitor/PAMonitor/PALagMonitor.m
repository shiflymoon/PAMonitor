//
//  PALagMonitor.m
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import "PALagMonitor.h"

#import "PACallStack.h"
#import "PACallStackModel.h"
#import "PACPUMonitor.h"
#import "PALagDB.h"
#import "PASuspendResumeThread.h"

//http://ios.jobbole.com/93085/
@interface PALagMonitor() {
    int timeoutCount;
    CFRunLoopObserverRef runLoopObserver;
@public
    dispatch_semaphore_t dispatchSemaphore;
    dispatch_semaphore_t eventSemaphore;
    CFRunLoopActivity runLoopActivity;
}
@property (nonatomic, strong) dispatch_source_t cpuMonitorTimer;
@end

@implementation PALagMonitor

/*!
 *  @brief  监听runloop状态为before waiting状态下是否卡顿
 *  系统发出beforeWaiting RunLoop通知后，会通过输入源（souce0和souce1）来唤醒，而此时的
 *  source0和source1也可能造成卡顿
 */
static inline dispatch_queue_t pa_event_monitor_queue() {
    static dispatch_queue_t pa_event_monitor_queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pa_event_monitor_queue = dispatch_queue_create("com.pingan.pa_event_monitor_queue", NULL);
    });
    return pa_event_monitor_queue;
}

/*!
 *  @brief  监听runloop状态在after waiting和before sources之间
 */
static inline dispatch_queue_t pa_fluecy_monitor_queue() {
    static dispatch_queue_t pa_fluecy_monitor_queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pa_fluecy_monitor_queue = dispatch_queue_create("com.pingan.pa_monitor_queue", NULL);
    });
    return pa_fluecy_monitor_queue;
}

#pragma mark - Interface
+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t dispatchOnce;
    dispatch_once(&dispatchOnce, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)beginMonitor {
    self.isMonitoring = YES;
   
    //子线程timer，防止主线程CPU过高，timer无法执行。
    //监测 CPU 消耗
    self.cpuMonitorTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_timer(self.cpuMonitorTimer,DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC, 0.01 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.cpuMonitorTimer, ^{
        [self updateCPUInfo];
    });
    dispatch_resume(self.cpuMonitorTimer);

    //监测卡顿
    if (runLoopObserver) {
        return;
    }
    dispatchSemaphore = dispatch_semaphore_create(0); //Dispatch Semaphore保证同步，信号量为0默认阻塞等待唤醒
    eventSemaphore = dispatch_semaphore_create(0);//检测beforewaiting阻塞，信号量为0默认阻塞等待唤醒
    //创建一个观察者
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    runLoopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                              kCFRunLoopAllActivities,
                                              YES,
                                              0,
                                              &runLoopObserverCallBack,
                                              &context);
    //将观察者添加到主线程runloop的common模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    
    //创建子线程监控(beforesource和afterwaiting）
    dispatch_async(pa_fluecy_monitor_queue(), ^{
        //子线程开启一个持续的loop用来进行监控
        [self loopDetectSouceRunStuck];//检测运行的source卡顿
    });
    
    dispatch_async(pa_event_monitor_queue(), ^{
        [self loopDetectInputSourceStuck];//检测inputsource卡顿
    });
    
}

- (void)endMonitor {
    self.isMonitoring = NO;
    dispatch_source_cancel(self.cpuMonitorTimer);
    if (!runLoopObserver) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    CFRelease(runLoopObserver);
    runLoopObserver = NULL;
}

#pragma mark - Private


-(void) loopDetectInputSourceStuck
{
    while (self.isMonitoring) {
        if (runLoopActivity == kCFRunLoopBeforeWaiting) {
            __block BOOL timeOut = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                timeOut = NO;
                dispatch_semaphore_signal(self->eventSemaphore);
            });

            [NSThread sleepForTimeInterval: 0.02];//时间必须足够长 0.02秒
            if (timeOut) {
                [self recordStuckOperation];
            }
            dispatch_wait(eventSemaphore, DISPATCH_TIME_FOREVER);//
        }
    }
}

-(void) loopDetectSouceRunStuck
{
    while (self.isMonitoring) {
        long semaphoreWait = dispatch_semaphore_wait(dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, STUCKMONITORRATE * NSEC_PER_MSEC));
        if (semaphoreWait != 0) {
            if (!runLoopObserver) {
                timeoutCount = 0;
                dispatchSemaphore = 0;
                runLoopActivity = 0;
                return;
            }
            //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够检测到是否卡顿
            //BeforeSources到BeforeWaiting会处理souce0事件，AfterWaiting后会处理source1事件
            if (runLoopActivity == kCFRunLoopBeforeSources || runLoopActivity == kCFRunLoopAfterWaiting) {
                //出现三次出结果
                if (++timeoutCount < 3) {//如果某一个runloop中souce0和souce1事件不能连续触发3次超时，就不可能检测出卡顿，因为会被beforetimer或者beforewaiting重置计数器
                    continue;
                }
                
                [self recordStuckOperation];
               
            } //end activity
        }// end semaphore wait
        timeoutCount = 0;//如果主线程不忙其他runloop比如BeforeTimer状态会重置计数器
    }// end while
}

- (void) recordStuckOperation
{
    pamc_suspendEnvironment();
    NSString *stackStr = [PACallStack callStackWithType:PACallStackTypeMain];
    pamc_resumeEnvironment();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if(![stackStr containsString:PALagMonitorPreExclude()]){
            PACallStackModel *model = [[PACallStackModel alloc] init];
            model.stackStr = stackStr;
            model.isStuck = YES;
            [[PALagDB sharedInstance] increaseWithStackModel:model] ;
            PALog(@"Main Thread Stuck , thread stack：\n%@",stackStr);
        }
    });
   
}

- (void)updateCPUInfo {
    [PACPUMonitor updateCPU];
}

#define LOG_RUNLOOP_ACTIVITY 0
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    PALagMonitor *lagMonitor = (__bridge PALagMonitor*)info;
    lagMonitor->runLoopActivity = activity;
    
    dispatch_semaphore_t semaphore = lagMonitor->dispatchSemaphore;
    dispatch_semaphore_signal(semaphore);
    
#if LOG_RUNLOOP_ACTIVITY
    switch (activity) {
        case kCFRunLoopEntry:
            NSLog(@"runloop entry");
            break;
            
        case kCFRunLoopExit:
            NSLog(@"runloop exit");
            break;
            
        case kCFRunLoopAfterWaiting:
            NSLog(@"runloop after waiting");
            break;
            
        case kCFRunLoopBeforeTimers:
            NSLog(@"runloop before timers");
            break;
            
        case kCFRunLoopBeforeSources:
            NSLog(@"runloop before sources");
            break;
            
        case kCFRunLoopBeforeWaiting:
            NSLog(@"runloop before waiting");
            break;
            
        default:
            break;
    }
#endif
}



static inline NSString * PALagMonitorPreExclude(void){
    NSString * PALagMonitorStr = NSStringFromClass([PALagMonitor class]);
    NSString *updateCPUInfoStr = NSStringFromSelector(@selector(updateCPUInfo));
    static NSString * excludeStr = @"";
    if(![excludeStr length]){
        assert([[PALagMonitor new] respondsToSelector:@selector(updateCPUInfo)]);
        excludeStr = [NSString stringWithFormat:@"-[%@ %@]",PALagMonitorStr,updateCPUInfoStr];
    }
    return excludeStr;
}

@end

