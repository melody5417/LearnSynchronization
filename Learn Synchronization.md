# Learn Synchronization

OS X 和 iOS 的多线程安全开发一直都容易成为 App 开发的坑，处理不好就容易出现 crash 或各种各样奇怪的现象，这次下定决心深入研究「多线程开发中的同步工具」。[苹果官方资料](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html)

## Synchronization Tools

同步工具包括：

 * Atomic Operations
 * Memory Barriers and Volatile Variables
 * Locks
 * Conditions
 * Perform Selector Routines

本篇文章主要研究 Locks 和 Conditions。

## Tips for Thread-Safe Designs

### Avoid Synchronization Altogether
使用锁一定会对性能和响应速度有影响，所以尽量解耦设计，减少交互和依赖的模块，从而减少锁的使用。

### Be Aware of Threats to Code Correctness
看下面的🌰：

```
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[arrayLock unlock];
 
[anObject doSomething];
```
array是非线程安全的，所以在修改array的时候加了锁。但是doSomthing方法没有加锁，这里就会出现问题：如果在 unlock 之后，有另外一个线程清空了array，array中的对象被释放，此时anObject指向的是非合法的内存地址，在调用doSomething方法就会出现问题。

为了解决问题，可能会移动doSomething的顺序，将其移入锁内保护。但是，此时又可能出现另一个问题，如果doSomething是一个耗时很长的方法，那就会一直等待，成为性能瓶颈。

解决这个问题的根本在于 “a memory management issue that is triggered only by the presence of other threads. Because it can be released by another thread, a better solution would be to retain anObject before releasing the lock. This solution addresses the real problem of the object being released and does so without introducing a potential performance penalty.”

修正后的代码如下：

```
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[anObject retain];
[arrayLock unlock];
 
[anObject doSomething];
[anObject release];
```
更多 [官方tips](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html#//apple_ref/doc/uid/10000057i-CH12-SW1)

### Watch Out for Deadlocks and Livelocks
[死锁和活锁的解释](http://www.cnblogs.com/ktgu/p/3529143.html)

关于“死锁与活锁”的比喻：
死锁：迎面开来的汽车A和汽车B过马路，汽车A得到了半条路的资源（满足死锁发生条件1：资源访问是排他性的，我占了路你就不能上来，除非你爬我头上去），汽车B占了汽车A的另外半条路的资源，A想过去必须请求另一半被B占用的道路（死锁发生条件2：必须整条车身的空间才能开过去，我已经占了一半，尼玛另一半的路被B占用了），B若想过去也必须等待A让路，A是辆兰博基尼，B是开奇瑞QQ的屌丝，A素质比较低开窗对B狂骂：快给老子让开，B很生气，你妈逼的，老子就不让（死锁发生条件3：在未使用完资源前，不能被其他线程剥夺），于是两者相互僵持一个都走不了（死锁发生条件4：环路等待条件），而且导致整条道上的后续车辆也走不了。
 
活锁：马路中间有条小桥，只能容纳一辆车经过，桥两头开来两辆车A和B，A比较礼貌，示意B先过，B也比较礼貌，示意A先过，结果两人一直谦让谁也过不去。

The best way to avoid both deadlock and livelock situations is to take only one lock at a time. If you must acquire more than one lock at a time, you should make sure that other threads do not try to do something similar.

## Using Locks
### Using a POSIX Mutex Lock

POSIX mutex lock 有以下几个方法：

```
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
int pthread_mutex_init(pthread_mutex_t *mutex, 
    const pthread_mutexattr_t *attr);
int pthread_mutex_destroy(pthread_mutex_t *mutex);
int pthread_mutex_lock(pthread_mutex_t *mutex);
int pthread_mutex_trylock(pthread_mutex_t *mutex);
int pthread_mutex_unlock(pthread_mutex_t *mutex);
```

```
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

```

### Using the NSLock Class
所有锁实际都是实现了 NSLocking 协议，定义了 lock 和 unlock 方法。
NSLock 类使用的是 POSIX 来实现它的锁操作，需要注意的是必须在同一线程内发送 unlock 消息，否则会发生不确定的情况。NSLock 不能用来实现迭代锁，因为如果发生两次 lock 消息的话，整个线程会被永久锁住。

```
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
```

### Using the @synchronized Directive
作为一种预防措施，@synchronized块隐式的添加一个异常处理例程来保护代码。该处理例程会在异常抛出的时候自动的释放互斥锁。这意味着为了使用@synchronized指令，你必须在你的代码中启用异常处理。如果你不想让隐式的异常处理例程带来额外的开销，你应该考虑使用锁的类。

```
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

```

### Using an NSRecursiveLock Object
首先来看一个🌰：

```
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
```
运行这段代码，会发现报错，发生死锁：

	2017-05-31 11:54:01.467100+0800 LearnLockIniOSMultiThreading[1863:602383] method1
	2017-05-31 11:54:06.471439+0800 LearnLockIniOSMultiThreading[1863:602383] *** -[NSLock lock]: deadlock (<NSLock: 0x6180000c1340> '(null)')
	2017-05-31 11:54:06.471478+0800 LearnLockIniOSMultiThreading[1863:602383] *** Break on _NSLockError() to debug.

这里就是之前说的，NSLock 不能用来实现迭代锁，因为如果发生两次 lock 消息的话，整个线程会被永久锁住。这时就应该使用 NSRecursiveLock。

NSRecursiveLock类定义了可以被同一线程获取多次而不会造成死锁的锁。NSRecursiveLock可以被用在递归调用中，一个递归锁会跟踪它被多少次成功获得了。每次成功的获得该锁都必须平衡调用锁住和解锁的操作。只有所有的锁住和解锁操作都平衡的时候，锁才真正被释放给其他线程获得。这种类型的锁通常被用在一个递归函数里面来防止递归造成阻塞线程，只有当多次获取的锁全部释放时，NSRecursiveLock才能被其他线程获取。

```
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

```
因为一个递归锁不会被释放直到所有锁的调用平衡使用了解锁操作，所以你必须仔细权衡是否决定使用锁对性能的潜在影响。长时间持有一个锁将会导致其他线程阻塞直到递归完成。如果你可以重写你的代码来消除递归或消除使用一个递归锁，你可能会获得更好的性能。

### Using an NSConditionLock Object
NSConditionLock定义了一个条件互斥锁，也就是当条件成立时就会获取到锁，反之就会释放锁。它的行为和Codition有点类似，但是它们的实现非常不同。因为这个特性，条件锁可以被用在有特定顺序的处理流程中，当多线程需要以特定的顺序来执行任务的时候，你可以使用一个NSConditionLock对象，比如生产者-消费者问题。

NSConditionLock的锁住和解锁方法可以任意组合使用。比如，你可以使用unlockWithCondition:和lock消息，或使用lockWhenCondition:和unlock消息。当然，后面的组合可以解锁一个锁但是可能没有释放任何等待某特定条件值的线程。

```
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
```

### Using an NSDistributedLock Object
NSDistributedLock是跨进程的分布式锁，锁本身是一个高效的互斥锁，底层是用文件系统实现的互斥锁。如果Path不存在，那么在tryLock返回YES时，会自动创建path。在结束的时候Path会被清除，所以在选择path的时候，应该选择一个不存在的路径，以防止误操作。

NSDistributedLock没有实现NSLocking协议，所以没有会阻塞线程的lock方法，取而代之的是非阻塞的tryLock方法。NSDistributedLock类可以被多台主机上的多个应用程序使用来限制对某些共享资源的访问。对于一个可用的NSDistributedLock对象，锁必须由所有使用它的程序写入。

NSDistributedLock只有在锁持有者显式地释放后才会被释放，也就是说当持有锁的应用崩溃后，其他应用就不能访问受保护的共享资源了。在这种情况下，你可以使用breadLock方法来打破现存的锁以便你可以获取它。但是通常应该避免打破锁，除非你确定拥有进程已经死亡并不可能再释放该锁。和其他类型的锁一样，当你使用NSDistributedLock对象时，你可以通过调用unlock方法来释放它。

```
appA的代码：
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;
        NSDistributedLock *lock = [[NSDistributedLock alloc] initWithPath:[desktopPath stringByAppendingPathComponent:@"testDistributedLock__"]];

        [lock breakLock];
        [lock tryLock];
        sleep(10);
        [lock unlock];
        NSLog(@"appA OK");
    });
```

```
appB的代码：
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *desktopPath = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES).firstObject;
        NSDistributedLock *lock = [[NSDistributedLock alloc] initWithPath:[desktopPath stringByAppendingPathComponent:@"testDistributedLock__"]];

        while (![lock tryLock]) {
            NSLog(@"appB waiting");
            sleep(1);
        }

        [lock unlock];
        NSLog(@"appB OK");
    });
```
### Using the NSCondition Class

NSCondition 是互斥锁和条件锁的结合体，也就是一个线程在等待信号而阻塞时，可以被另外一个线程唤醒。需要注意的是，由于操作系统实现的差异，即使在代码中没有发送signal消息，线程也有可能被唤醒，所以需要增加谓词变量来保证程序的正确性。

* wait：释放互斥量，使当前线程等待，切换到其它线程执行。
* waitUntilDate：释放互斥量，使当前线程等待到某一个时间，切换到其它线程执行。
* signal：唤醒一个其它等待该条件变量的线程
* broadcast：唤醒所有其它等待该条件变量的线程

```
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
```

### Using POSIX Conditions
POSIX 线程条件锁需要条件锁和互斥锁配合。

```
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
```
### Using GCD dispatch_sempaphore
dispatch_sempaphore 是 GCD 用来同步的一种方式，它主要有两个应用： 保持线程同步 和 为线程加锁。提供以下方法：（[参考](http://www.jianshu.com/p/a84c2bf0d77b)）

* dispatch_semaphore_t dispatch_semaphore_create(long value)：方法接收一个long类型的参数, 返回一个dispatch_semaphore_t类型的信号量，值为传入的参数
* long dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout)：接收一个信号和时间值，若信号的信号量为0，则会阻塞当前线程，直到信号量大于0或者经过输入的时间值；若信号量大于0，则会使信号量减1并返回，程序继续住下执行
* long dispatch_semaphore_signal(dispatch_semaphore_t dsema)：使信号量加1并返回

#### 保持线程同步

```
	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    __block int j = 0;
    dispatch_async(queue, ^{
        j = 100;
        dispatch_semaphore_signal(semaphore);
    });

    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"finish j = %zd", j);
```
运行代码，输出 j=100。 如果注释掉 wait 这句，则输出 j=0。
原因：block 是异步添加到并行队列 queue 里，所以主线程是越过 block 直接到 dispatch_semaphore_wait 这一行，此时，semaphore 信号量为0，时间值为 Forever，所以一定会阻塞主线程，block到异步并行队列执行，发送signal，使信号量+1，此时主线程继续执行，起到了同步的效果。

#### 为线程加锁
当 semaphore 信号量为1时,可以用于加锁。

```
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
```

### Using OSSpinLock

先声明一下，OSSpinLock 在iOS10 和 macOS 10.12已经被废弃， 苹果给出了替代方案 os_unfair_lock。[参考](https://gist.github.com/steipete/36350a8a60693d440954b95ea6cbbafc)

现在来学习一下OSSpinLock，主要提供以下方法：

* typedef int32_t OSSpinLock;
* bool    OSSpinLockTry( volatile OSSpinLock *__lock );
* void    OSSpinLockLock( volatile OSSpinLock *__lock );
* void    OSSpinLockUnlock( volatile OSSpinLock *__lock );

OSSpinLock是一种自旋锁，和 NSLock 不同的是 NSLock 请求加锁失败的话，会先轮询，但一秒过后便会使线程进入 waiting 状态，等待唤醒。而 OSSpinLock 会一直轮询，等待时会消耗大量 CPU 资源，不适用于较长时间的任务。