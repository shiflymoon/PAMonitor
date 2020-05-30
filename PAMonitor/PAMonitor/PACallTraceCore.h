//
//  PACallTraceCore.h
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/22.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#ifndef PACallTraceCore_h
#define PACallTraceCore_h

#include <stdio.h>
#include <objc/objc.h>

typedef struct {
    __unsafe_unretained Class cls;
    SEL sel;
    uint64_t time; // us (1/1000 ms)
    int depth;
} paCallRecord;

extern void paCallTraceStart(void);
extern void paCallTraceStop(void);

extern void paCallConfigMinTime(uint64_t us); //default 1000
extern void paCallConfigMaxDepth(int depth);  //default 3

extern paCallRecord *paGetCallRecords(int *num);
extern void paClearCallRecords(void);
#endif /* PACallTraceCore_h */
