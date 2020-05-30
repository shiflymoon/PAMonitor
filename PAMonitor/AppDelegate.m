//
//  AppDelegate.m
//  PAMonitor
//
//  Created by 史贵岭 on 2019/4/18.
//  Copyright © 2019年 史贵岭. All rights reserved.
//

#import "AppDelegate.h"
#import "PALagMonitor.h"
#include <sys/time.h>
#import <AdSupport/AdSupport.h>


@interface AppDelegate ()
@property(nonatomic,strong) dispatch_semaphore_t semaphore;
@end

@implementation AppDelegate


- (int64_t)freeDiskSpace {
    int64_t space = 0;
    @try {
        NSDictionary *fattributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
        NSNumber *tmp = [fattributes objectForKey:NSFileSystemFreeSize];
        space = [tmp longLongValue];
    }
    @catch (...) {
    }
    
    return space;
}

- (dispatch_queue_t) saveLogQueue
{
    static dispatch_queue_t logQueue;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logQueue = dispatch_queue_create("com.skyeye.analytics.network.queue.logQueue", DISPATCH_QUEUE_SERIAL);
    });
    
    return logQueue;
}

- (void) saveLogMessage2File:(NSString *) message
{
    dispatch_async([self saveLogQueue], ^{
        @autoreleasepool {
            if([self freeDiskSpace] <= 104857600){//100M
                return;
            }
            
            NSFileHandle *outFile = nil;
            @try {
                
                NSString * filePath = [self logFilePath];
                NSFileManager* manager = [NSFileManager defaultManager];
                
                if ([manager fileExistsAtPath:filePath]){
                    NSDictionary * fileAttributeDic = [manager attributesOfItemAtPath:filePath error:nil];
                    unsigned long long fileSize =  [fileAttributeDic fileSize];
                    NSDate * fileCreateDate = [fileAttributeDic fileCreationDate];
                    long long  interval = [[NSDate date] timeIntervalSinceDate:fileCreateDate];
                    if(fileSize > 10485760 || llabs(interval) >= 345600){ // 345600 = 4 * 24 * 3600 = 4天，10485760 = 10M = 10 * 1024 * 1024
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                    }
                }
                
                static NSDateFormatter * format = nil;
                if(!format){
                    format = [NSDateFormatter new];
                    [format setDateFormat:@"yyyy-MM-dd HH:mm:ss.sss"];
                }
                NSString * formatDate = [format stringFromDate:[NSDate date]];
                NSString * rtfMessage = [NSString stringWithFormat:@"%@\r\n%@\r\n\r\n",formatDate,message];
                
                NSData * data = [rtfMessage dataUsingEncoding:NSUTF8StringEncoding];
                
                
                //分块加密，解密
                int blockSize = 1024 ; //1kb大小
                NSRange dataRange;
                if(![[NSFileManager defaultManager] fileExistsAtPath:filePath ]){ //本地不存在文件
                    NSInteger times = data.length % blockSize ? (data.length / blockSize +1):data.length /blockSize;
                    for(NSInteger i = 0 ; i < times;i++){
                        if(i == 0){
                            dataRange.location = 0;
                            dataRange.length = blockSize < data.length ? blockSize : data.length;
                            NSData * encodeBinaryData = [data subdataWithRange:dataRange];
                            [encodeBinaryData writeToFile:filePath atomically:YES];
                        }else {
                            dataRange.location = blockSize * i;
                            if(i == times -1){
                                dataRange.length = data.length % blockSize ? data.length % blockSize : blockSize ;
                            }
                            if(!outFile){
                                outFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
                            }
                            
                            NSData * encodeBinaryData = [data subdataWithRange:dataRange];
                            [outFile seekToEndOfFile];
                            [outFile writeData:encodeBinaryData];
                            [outFile synchronizeFile];
                            
                        }
                    }
                    
                    [outFile closeFile];
                    outFile = nil;
                }else{
                    NSDictionary * fileAttributeDic = [manager attributesOfItemAtPath:filePath error:nil];
                    unsigned long long fileSize =  [fileAttributeDic fileSize];
                    
                    //获取上次不够blockSize的数据，并解密处理、并且同新数据合并起来再分块加密
                    NSInteger leftSize = fileSize % blockSize;
                    NSFileHandle *outFile = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
                    NSMutableData * shouldEncodeMutableData = [NSMutableData data];
                    if(leftSize){
                        [outFile seekToFileOffset:fileSize-leftSize];
                        NSData * readData = [outFile readDataToEndOfFile];
                        
                        NSData * decodeReadData =  readData;
                        if(decodeReadData.length){//获取上次不够blockSize的数据
                            [shouldEncodeMutableData appendData:decodeReadData];
                        }
                    }
                    
                    //合并新数据
                    [shouldEncodeMutableData appendData:data];
                    
                    
                    NSInteger times = shouldEncodeMutableData.length % blockSize ? (shouldEncodeMutableData.length / blockSize +1):shouldEncodeMutableData.length /blockSize;
                    dataRange.location = 0;
                    dataRange.length = blockSize < shouldEncodeMutableData.length ? blockSize : shouldEncodeMutableData.length;
                    for(NSInteger i = 0 ; i < times;i++){
                        dataRange.location = blockSize * i;
                        if(i == times -1){
                            dataRange.length = shouldEncodeMutableData.length % blockSize ? shouldEncodeMutableData.length % blockSize : blockSize;
                        }
                        
                        NSData * encodeBinaryData = [shouldEncodeMutableData subdataWithRange:dataRange];
                        if(i == 0){
                            [outFile seekToFileOffset:fileSize-leftSize];//从上此不够blocksize地方开始覆盖数据
                        }else{
                            [outFile seekToEndOfFile];
                        }
                        
                        [outFile writeData:encodeBinaryData];
                        [outFile synchronizeFile];
                        
                    }
                    
                    [outFile closeFile];
                    outFile = nil;
                }
            } @catch (NSException *exception) {
                
            }@finally {
                if(outFile){
                    [outFile closeFile];
                }
                //dispatch_semaphore_signal(self.semaphore);
            }
            
        }
    });
}




-(NSString *) logFilePath
{
    NSString * filePath = nil;
    
    NSArray * basePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask, YES);
    NSString * cachesPath = [basePath objectAtIndex:0];
    cachesPath = [cachesPath stringByAppendingPathComponent:@"SkyEyeLogData.txt"];
    
    filePath = cachesPath.copy;
    
    return filePath;
    
}



- (void)redirectNSlogToDocumentFolder
{
    NSString *documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSDateFormatter *dateformat = [[NSDateFormatter  alloc]init];
    [dateformat setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *fileName = [NSString stringWithFormat:@"LOG-%@.txt",[dateformat stringFromDate:[NSDate date]]];
    NSString *logFilePath = [documentDirectory stringByAppendingPathComponent:fileName];
    
    // 先删除已经存在的文件
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    [defaultManager removeItemAtPath:logFilePath error:nil];
    
    NSLog(@"%@",logFilePath);
    
    // 将log输入到文件
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}

-(void) testMethod
{
    struct timeval now;
    gettimeofday(&now, NULL);
    long long timesec= now.tv_sec;
    long long timeusec = now.tv_usec;
    NSTimeInterval tt = [[NSDate date] timeIntervalSince1970];
    NSLog(@"aaa:%ld->%ld->%.6f->%ld",timesec,timesec % 100,tt,timeusec);
    uint64_t time = (now.tv_sec % 100) * 1000000 + now.tv_usec;
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
    NSString * str = @"- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions";
    [self testMethod];
    
    int i = 50%100;
    
    ASIdentifierManager * manager = [ASIdentifierManager sharedManager];
    if(manager.advertisingTrackingEnabled){
        NSLog(@"adsverId :%@",manager.advertisingIdentifier.UUIDString);
    }
/*
 //将NSLog重定向到文件
#ifdef DEBUG
    [self redirectNSlogToDocumentFolder];
#endif
 */
 
    PALog(@"Test");
    [[PALagMonitor sharedInstance] beginMonitor];
    
    //模拟CPU繁忙
  //  [self simulateCPUOver];
    
   
/*
   // self.semaphore =  dispatch_semaphore_create(4);
    for(int i=0;i<100000;i++){
      //  dispatch_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        [self saveLogMessage2File:[NSString stringWithFormat:@"%@--%d\r\n",str,i]];
    }*/
    
    // Override point for customization after application launch.
    return YES;
}

-(void) simulateCPUOver
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        while (1) {
            [NSThread sleepForTimeInterval:1.0];
        }
    });

}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
