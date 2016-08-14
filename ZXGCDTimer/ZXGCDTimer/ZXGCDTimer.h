//
//  ZXGCDTimer.h
//  iOSAninatuib
//
//  Created by csbzhixing on 16/8/10.
//  Copyright © 2016年 csbzhixing All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ZXGCDTimerType) {
    ZXAbandonPreviousAction, // 废除同一个timer之前的任务
    ZXMergePreviousAction    // 将同一个timer之前的任务合并到新的任务中
};

@interface ZXGCDTimer : NSObject

- (instancetype)initDispatchTimerWithName:(NSString *)timerName
                             timeInterval:(double)interval
                                    queue:(dispatch_queue_t)queue
                                  repeats:(BOOL)repeats
                                   action:(dispatch_block_t)action
                               actionType:(ZXGCDTimerType)type;

@property (nonatomic, strong, readonly) dispatch_queue_t serialQueue;
@property (nonatomic, assign, readonly) BOOL repeat;
@property (nonatomic, assign, readonly) NSTimeInterval timeInterval;
@property (nonatomic, assign, readonly) ZXGCDTimerType type;
@property (nonatomic, strong, readonly) NSString *timerName;
@property (nonatomic, strong,readonly) NSArray *actionBlockCache;

- (void)addActionBlock:(dispatch_block_t)action actionType:(ZXGCDTimerType)type;

@end

@interface ZXGCDTimerManager : NSObject

+ (instancetype)sharedInstance;

// if the timer is exited,the timeInterval here is useless
// 如果已经初始化过，这里设置timerInterVal是无效的
- (void)adddDispatchTimerWithName:(NSString *)timerName
                     timeInterval:(NSTimeInterval)interval
                            queue:(dispatch_queue_t)queue
                          repeats:(BOOL)repeats
                       actionType:(ZXGCDTimerType)type
                           action:(dispatch_block_t)action;

- (void)scheduledDispatchTimerWithName:(NSString *)timerName
                          timeInterval:(NSTimeInterval)interval
                                 queue:(dispatch_queue_t)queue
                               repeats:(BOOL)repeats
                            actionType:(ZXGCDTimerType)type
                                action:(dispatch_block_t)action;

- (void)scheduleTimer:(NSString *)timerName;

- (void)fireTimer:(NSString *)timerName;

- (void)cancelTimerWithName:(NSString *)timerName;

- (void)suspendTimer:(NSString *)timerName;

- (void)resumeTimer:(NSString *)timerName;

@end
