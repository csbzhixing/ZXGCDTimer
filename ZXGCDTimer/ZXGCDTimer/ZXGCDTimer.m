//
//  ZXGCDTimer.m
//  iOSAninatuib
//
//  Created by csbzhixing on 16/8/10.
//  Copyright © 2016年 csbzhixing. All rights reserved.
//

#import "ZXGCDTimer.h"

#if OS_OBJECT_USE_OBJC
#define zx_gcd_property_qualifier strong
#define zx_release_gcd_object(object)
#else
#define zx_gcd_property_qualifier assign
#define zx_release_gcd_object(object) dispatch_release(object)
#endif

@interface ZXGCDTimer ()

@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, copy) dispatch_block_t action;
@property (nonatomic, assign) BOOL repeat;
@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, strong) NSString *timerName;
@property (nonatomic, assign) ZXGCDTimerType type;
@property (nonatomic, strong) NSArray *actionBlockCache;

@end

@implementation ZXGCDTimer

- (instancetype)initDispatchTimerWithName:(NSString *)timerName
                             timeInterval:(double)interval
                                    queue:(dispatch_queue_t)queue
                                  repeats:(BOOL)repeats
                                   action:(dispatch_block_t)action
                               actionType:(ZXGCDTimerType)type {

    if (self = [super init]) {
        self.timeInterval = interval;
        self.repeat = repeats;
        self.action = action;
        self.timerName = timerName;
        self.type = type;

        NSString *privateQueueName = [NSString stringWithFormat:@"com.mindsnacks.msweaktimer.%p", self];

        self.serialQueue =
            dispatch_queue_create([privateQueueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(self.serialQueue, queue);

        NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:action, nil];

        self.actionBlockCache = array;
    }

    return self;
}

- (void)addActionBlock:(dispatch_block_t)action actionType:(ZXGCDTimerType)type {
    NSMutableArray *array = [self.actionBlockCache mutableCopy];
    self.type = type;
    switch (type) {
    case ZXAbandonPreviousAction: {
        [array removeAllObjects];
        [array addObject:action];
        self.actionBlockCache = array;
        break;
    }
    case ZXMergePreviousAction: {
        [array addObject:action];
        self.actionBlockCache = array;
        break;
    }
    }
}

@end

@interface ZXGCDTimerManager ()
@property (nonatomic, strong) NSMutableDictionary *timerObjectCache;
@property (nonatomic, strong) NSMutableDictionary *timerContainer;
@end

@implementation ZXGCDTimerManager

#pragma mark -  liftCycle

+ (instancetype)sharedInstance {
    static ZXGCDTimerManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ZXGCDTimerManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        self.timerContainer = [NSMutableDictionary dictionary];
    }

    return self;
}

#pragma mark -  public

- (void)adddDispatchTimerWithName:(NSString *)timerName
                     timeInterval:(NSTimeInterval)interval
                            queue:(dispatch_queue_t)queue
                          repeats:(BOOL)repeats
                       actionType:(ZXGCDTimerType)type
                           action:(dispatch_block_t)action {

    NSParameterAssert(timerName);

    if (nil == queue) {
        queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }

    ZXGCDTimer *timer = self.timerObjectCache[timerName];

    if (!timer) {
        timer = [[ZXGCDTimer alloc] initDispatchTimerWithName:timerName
                                                 timeInterval:interval
                                                        queue:queue
                                                      repeats:repeats
                                                       action:action
                                                   actionType:type];
        self.timerObjectCache[timerName] = timer;

    } else {
        [timer addActionBlock:action actionType:type];
    }
    dispatch_source_t timer_t = self.timerContainer[timerName];
    if (!timer_t) {
        timer_t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timer.serialQueue);
        dispatch_resume(timer_t);
        [self.timerContainer setObject:timer_t forKey:timerName];
    }

    if (timer.actionBlockCache.count > 1) {
        [self scheduleTimer:timerName];
    }
}

- (void)scheduledDispatchTimerWithName:(NSString *)timerName
                          timeInterval:(NSTimeInterval)interval
                                 queue:(dispatch_queue_t)queue
                               repeats:(BOOL)repeats
                            actionType:(ZXGCDTimerType)type
                                action:(dispatch_block_t)action {
    [self adddDispatchTimerWithName:timerName
                       timeInterval:interval
                              queue:queue
                            repeats:repeats
                         actionType:type
                             action:action];
    [self scheduleTimer:timerName];
}

- (void)scheduleTimer:(NSString *)timerName {
    NSParameterAssert(timerName);

    dispatch_source_t timer_t = self.timerContainer[timerName];
    NSAssert(timer_t, @"timerName is not vaild");

    ZXGCDTimer *timer = self.timerObjectCache[timerName];

    dispatch_source_set_timer(timer_t, dispatch_time(DISPATCH_TIME_NOW, timer.timeInterval * NSEC_PER_SEC),
                              timer.timeInterval * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);

    __weak typeof(self) weakSelf = self;

    switch (timer.type) {
    case ZXAbandonPreviousAction: {

        dispatch_source_set_event_handler(timer_t, ^{
            timer.action();

            if (!timer.repeat) {
                [weakSelf cancelTimerWithName:timerName];
            }
        });
        break;
    }
    case ZXMergePreviousAction: {

        dispatch_source_set_event_handler(timer_t, ^{
            [timer.actionBlockCache enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                dispatch_block_t action = obj;
                action();
            }];
        });

        break;
    }
    }
}

- (void)fireTimer:(NSString *)timerName {
    ZXGCDTimer *timer = self.timerObjectCache[timerName];
    [timer.actionBlockCache enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        dispatch_block_t action = obj;
        action();
    }];
}

- (void)cancelTimerWithName:(NSString *)timerName {
    dispatch_source_t timer = self.timerContainer[timerName];

    if (!timer) {
        return;
    }

    [self.timerContainer removeObjectForKey:timerName];
    dispatch_source_cancel(timer);

    [self.timerObjectCache removeObjectForKey:timerName];
}

- (void)suspendTimer:(NSString *)timerName {
    dispatch_source_t timer = self.timerContainer[timerName];

    dispatch_suspend(timer);
}

- (void)resumeTimer:(NSString *)timerName {
    dispatch_source_t timer = self.timerContainer[timerName];

    dispatch_resume(timer);
}

#pragma mark -  Assoicate

- (NSMutableDictionary *)timerContainer {
    if (!_timerContainer) {
        _timerContainer = [[NSMutableDictionary alloc] init];
    }
    return _timerContainer;
}

- (NSMutableDictionary *)timerObjectCache {
    if (!_timerObjectCache) {
        _timerObjectCache = [[NSMutableDictionary alloc] init];
    }
    return _timerObjectCache;
}

#pragma mark - Private

- (BOOL)existTimer:(NSString *)timerName {
    if (self.timerObjectCache[timerName]) {
        return YES;
    }
    return NO;
}

@end
