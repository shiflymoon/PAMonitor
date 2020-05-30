//
//  PASuspendResumeThread.c
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/24.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#include "PASuspendResumeThread.h"
#import <Foundation/Foundation.h>
#include <mach/mach.h>

static inline dispatch_queue_t pa_call_stack_queue() {
    static dispatch_queue_t pa_call_stack_queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        pa_call_stack_queue = dispatch_queue_create("com.pingan.pa_call_stack_queue", NULL);
    });
    return pa_call_stack_queue;
}


thread_t pathread_self()
{
    thread_t thread_self = mach_thread_self();
    mach_port_deallocate(mach_task_self(), thread_self);
    return (thread_t)thread_self;
}

#pragma mark -公开接口
#define PA_SUSPEND_OTHER_THREAD 1
void pamc_suspendEnvironment(void)
{
#if PA_SUSPEND_OTHER_THREAD
    PALog(@"Suspending environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = pathread_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;
    
    if((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS)
    {
        PALog(@"task_threads: %s", mach_error_string(kr));
        return;
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        thread_t thread = threads[i];
        if(thread != thisThread )
        {
            if((kr = thread_suspend(thread)) != KERN_SUCCESS)
            {
                // Record the error and keep going.
                PALog(@"thread_suspend (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);
    
    PALog(@"Suspend complete.");
#endif
}

void pamc_resumeEnvironment(void)
{
#if PA_SUSPEND_OTHER_THREAD
    PALog(@"Resuming environment.");
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    const thread_t thisThread = pathread_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;
    
    if((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS)
    {
        PALog(@"task_threads: %s", mach_error_string(kr));
        return;
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        thread_t thread = threads[i];
        if(thread != thisThread )
        {
            if((kr = thread_resume(thread)) != KERN_SUCCESS)
            {
                // Record the error and keep going.
                PALog(@"thread_resume (%08x): %s", thread, mach_error_string(kr));
            }
        }
    }
    
    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
    {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);
    
    PALog(@"Resume complete.");
#endif
}
