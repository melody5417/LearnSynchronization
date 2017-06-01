//
//  ViewController.m
//  LearnLockIniOSMultiThreading
//
//  Created by yiqiwang(王一棋) on 2017/5/31.
//  Copyright © 2017年 melody5417. All rights reserved.
//

#import "ViewController.h"
#import "TestObj.h"
#import <pthread.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // ---------------------------使用Atomic实现的方式---------------------------
//    [self lockWithAtomic];

    // ---------------------------使用NSLock实现的方式---------------------------
//    [self lockWithNSLock];

    // ---------------------------使用Synchronized实现的方式---------------------------
//    [self lockWithSynchronized];

    // ---------------------------使用pthread_mutext_t实现的方式---------------------------
//    [self lockWithPthread_Mutex_t];

    // ---------------------------使用semaphore实现的方式---------------------------
//    [self lockWithGCDSemaphore];
//    [self synchronizationWithGCDSemaphore];

    // ---------------------------使用NSRecursiveLock实现的方式---------------------------
//    [self testDeadlockWithNSLock];
//    [self lockWithNSRecursiveLock];

    // ---------------------------使用NSConditionLock实现的方式---------------------------
//    [self lockWithConditionLock];

    // ---------------------------使用NSDistributedLock实现的方式---------------------------
//    [self lockWithDistributedLock];

    // ---------------------------使用NSCondition实现的方式---------------------------
//    [self lockWithCondition];

    // ---------------------------使用POSIXCondition实现的方式---------------------------
//    [self lockWithPOSIXCondition];

    // ---------------------------使用OSSpinLock实现的方式---------------------------
    [self lockWithSpinLock];
}

- (void)lockWithAtomic {
    TestObj *obj = [[TestObj alloc] init];

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        obj.property1 = 10;
        obj.property2 = 20;
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        obj.property1 = 11;
        obj.property2 = 21;
    });

    // 线程3
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        obj.property1 = 12;
        obj.property2 = 22;
    });

    // 线程4
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"4: property1:%lu, property2:%lu", obj.property1, obj.property2);
    });

    // 线程5
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        obj.property1 = 14;
        obj.property2 = 24;
    });

    // 线程6
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"6: property1:%lu, property2:%lu", obj.property1, obj.property2);
    });

    /**
     * Demo没有模拟出真正的问题
     * Atomic 只是确定在read时不会读取到partial write的情况
     * 但是Atomic仍然会出现数据不一致的问题
     * 例如：
     * 一个persion实例，线程1修改其firstName， 线程2修改其secondName，线程3读取其fullName
     * 则fullName读取时只能确定之前的修改操作是执行完全的，但是可能线程1或线程2某个线程未执行，进而得到的fullName数据不一致。
     */
}

- (void)lockWithNSLock {

    TestObj *obj = [[TestObj alloc] init];
    NSLock *lock = [[NSLock alloc] init];

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lock];
        NSLog(@"线程1 lock");
        [obj method1];
        sleep(2);
        [lock unlock];
        NSLog(@"线程1 unLock");
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 先 sleep 以保证线程2的代码后执行
        sleep(1);
        [lock lock];
        NSLog(@"线程2 lock");
        [obj method2];
        [lock unlock];
        NSLog(@"线程2 unLock");
    });
}

- (void)lockWithSynchronized {

    TestObj *obj = [[TestObj alloc] init];

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (obj) {
            [obj method1];
            sleep(10);
        }
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        @synchronized (obj) {
            [obj method2];
        }
    });

    /*
     * @synchronized块会隐式的添加一个异常处理来保护代码，该处理方法会在异常抛出的时候自动的释放互斥锁。
     * 所以如果不想让隐式的异常处理例程带来额外的开销，你可以考虑使用锁对象。
     */
}

- (void)lockWithPthread_Mutex_t {
    TestObj *obj = [[TestObj alloc] init];

    // 创建锁对象
    __block pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, NULL);

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pthread_mutex_lock(&mutex);
        [obj method1];
        sleep(5);
        pthread_mutex_unlock(&mutex);
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pthread_mutex_lock(&mutex);
        [obj method2];
        sleep(5);
        pthread_mutex_unlock(&mutex);
    });
}

- (void)lockWithGCDSemaphore {
    TestObj *obj = [[TestObj alloc] init];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        [obj method1];
        sleep(10);
        dispatch_semaphore_signal(semaphore);
    });

    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        [obj method2];
        dispatch_semaphore_signal(semaphore);
    });
}

- (void)synchronizationWithGCDSemaphore {
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block int j = 0;
    dispatch_async(queue, ^{
        j = 100;
        dispatch_semaphore_signal(semaphore);
    });

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"finish j = %zd", j);

    /**
     * 输出 j=100;
     * 如果注释掉 wait 这句，则输出 j=0;
     * 原因：block 是异步添加到一个并行队列里，所以主线程是越过block直接到 dispatch_semaphore_wait这一行，此时，semaphore信号量为0，时间值为Forever，所以一定会阻塞主线程，block到异步并行队列执行，发送signal，使信号量+1，此时主线程继续执行，起到了同步的效果。
     */
}

- (void)testDeadlockWithNSLock {

    //主线程中
    NSLock *theLock = [[NSLock alloc] init];
    TestObj *obj = [[TestObj alloc] init];

    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void(^TestMethod)(int);
        TestMethod = ^(int value)
        {
            [theLock lock];
            if (value > 0)
            {
                [obj method1];
                sleep(5);
                TestMethod(value-1);
            }
            [theLock unlock];
        };
        TestMethod(5);
    });

    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [theLock lock];
        [obj method2];
        [theLock unlock];
    });

    /**
     * 发生死锁
     * 2017-05-31 11:54:01.467100+0800 LearnLockIniOSMultiThreading[1863:602383] method1
     * 2017-05-31 11:54:06.471439+0800 LearnLockIniOSMultiThreading[1863:602383] *** -[NSLock lock]: deadlock (<NSLock: 0x6180000c1340> '(null)')
     * 2017-05-31 11:54:06.471478+0800 LearnLockIniOSMultiThreading[1863:602383] *** Break on _NSLockError() to debug.
     */

}

- (void)lockWithNSRecursiveLock {

    //主线程中
    NSRecursiveLock *theLock = [[NSRecursiveLock alloc] init];
    TestObj *obj = [[TestObj alloc] init];

    //线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void(^TestMethod)(int);
        TestMethod = ^(int value)
        {
            [theLock lock];
            if (value > 0)
            {
                [obj method1];
                sleep(5);
                TestMethod(value-1);
            }
            [theLock unlock];
        };
        TestMethod(5);
    });

    //线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        [theLock lock];
        [obj method2];
        [theLock unlock];
    });

    /**
     * 将NSLock更改为NSRecursviewLock 死锁解决了
     * The NSRecursiveLock class defines a lock that can be acquired multiple times by the same thread without causing the thread to deadlock. 
     * A recursive lock keeps track of how many times it was successfully acquired. 
     * Each successful acquisition of the lock must be balanced by a corresponding call to unlock the lock. 
     * Only when all of the lock and unlock calls are balanced is the lock actually released so that other threads can acquire it.
     * As its name implies, this type of lock is commonly used inside a recursive function to prevent the recursion from blocking the thread. 
     * You could similarly use it in the non-recursive case to call functions whose semantics demand that they also take the lock.
     */
    
}

- (void)lockWithConditionLock {
    NSConditionLock *lock = [[NSConditionLock alloc] init];

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i <= 2; i++) {
            [lock lock];
            NSLog(@"thread1:%d", i);
            sleep(2);
            [lock unlockWithCondition:i];
        }
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [lock lockWhenCondition:2];
        NSLog(@"thread2");
        [lock unlock];
    });

    /**
     * 当涉及到满足一定条件的情况下才能打开锁 可以使用NSConditionLock 不要和Condition混淆！
     * An NSConditionLock object defines a mutex lock that can be locked and unlocked with specific values. You should not confuse this type of lock with a condition (see Conditions). The behavior is somewhat similar to conditions, but is implemented very differently.

     * Typically, you use an NSConditionLock object when threads need to perform tasks in a specific order, such as when one thread produces data that another consumes. While the producer is executing, the consumer acquires the lock using a condition that is specific to your program. (The condition itself is just an integer value that you define.) When the producer finishes, it unlocks the lock and sets the lock condition to the appropriate integer value to wake the consumer thread, which then proceeds to process the data.

     * The locking and unlocking methods that NSConditionLock objects respond to can be used in any combination. For example, you can pair a lock message with unlockWithCondition:, or a lockWhenCondition: message with unlock. Of course, this latter combination unlocks the lock but might not release any threads waiting on a specific condition value.
     */
}

- (void)lockWithDistributedLock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;
        NSDistributedLock *lock = [[NSDistributedLock alloc] initWithPath:[desktopPath stringByAppendingPathComponent:@"testDistributedLock__"]];

        [lock breakLock];
        [lock tryLock];
        sleep(10);
        [lock unlock];
        NSLog(@"appA OK");
    });

    /**
     * NSDistributedLock锁不同之处在于 它是应用于多个进程或多个程序之间的。
     * NSDistributedLock的实现是通过文件系统。如果path不存在，那么在tryLock返回YES时，会自动创建path。
     * 在结束的时候path会被清除，所以在选择path的时候，应该选择一个不存在的路径，以防止误操作。
     * NSDistributedLock并非继承自NSLock，没有lock方法。
     * The NSDistributedLock class defines an object that multiple applications on multiple hosts can use to restrict access to some shared resource, such as a file.
     */
}

- (void)lockWithCondition {
    NSCondition *condition = [[NSCondition alloc] init];
    NSMutableArray *products = [[NSMutableArray alloc] init];

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1:before lock");
        [condition lock];
        NSLog(@"线程1:after lock");

        while ([products count] == 0) {
            NSLog(@"线程1:wait");
            [condition wait];
        }
        [products removeAllObjects];
        NSLog(@"线程1:remove");
        [condition unlock];
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        NSLog(@"线程2: before lock");
        [condition lock];
        NSLog(@"线程2: after lock");
        [products addObject:[NSObject new]];
        [condition signal];
        NSLog(@"线程2 signal");
        [condition unlock];
    });
}

- (void)lockWithPOSIXCondition {
    __block pthread_cond_t condition;
    pthread_cond_init(&condition, NULL);

    __block pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, NULL);

    __block Boolean ready_to_go = false;

    // 线程1
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程1:before lock");
        pthread_mutex_lock(&mutex);
        NSLog(@"线程1:after lock");

        while (ready_to_go == false) {
            NSLog(@"线程1:wait");
            pthread_cond_wait(&condition, &mutex);
        }
        // Do work. (The mutex should stay locked.)

        // Reset the predicate and release the mutex.
        ready_to_go = false;
        NSLog(@"线程1:reset predicate");
        pthread_mutex_unlock(&mutex);
    });

    // 线程2
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        NSLog(@"线程2: before lock");
        pthread_mutex_lock(&mutex);
        NSLog(@"线程2: after lock");
        ready_to_go = true;
        pthread_cond_signal(&condition);
        NSLog(@"线程2 signal the other thread to begin work");
        pthread_mutex_unlock(&mutex);
    });
}

- (void)lockWithSpinLock {
    __block OSSpinLock theLock = OS_SPINLOCK_INIT;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        NSLog(@"线程1");
        sleep(10);
        OSSpinLockUnlock(&theLock);
        NSLog(@"线程1解锁成功");
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        OSSpinLockLock(&theLock);
        NSLog(@"线程2");
        OSSpinLockUnlock(&theLock);
    });

    /**
     * OSSpinLock 在iOS10 和 macOS 10.12已经被废弃。
     * warn: 'OSSpinLock' is deprecated: first deprecated in macOS 10.12 - Use os_unfair_lock() from <os/lock.h> instead
     */
}

@end
