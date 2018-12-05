# 面试题
1. 什么事runloop?有没有使用过？
2. RunLoop内部实现逻辑是什么？
3. RunLoop和线程有什么关系？
4. Timer和线程有什么关系？
5. 程序中添加每3s响应一次的Timer,当拖动TableView的时候可能无法响应怎么解决？
6. RunLoop是怎样响应用户操作的，具体流程是什么？
7. 说说RunLoop的几种状态？
8. RunLoop的mode作用是什么？

# 什么是RunLoop?
runloop是运行着的循环，在程序运行过程中循环做一些事情，如果没有runloop线程执行完任务就会立即退出；如果有runloop线程就可以不退出，并且时候等待用户输入操作。
Runloop可以在需要的时候执行任务，在没有任务的时候进行休眠，充分节省CPU。

# RunLoop基本作用
1. <strong>保证线程持续运行不退出</strong>:我们程序一旦启动，就会开一个主线程，同时会创建主线程对应的<strong>RunLoop</strong>,runloop保证了主线不会退出
，同时使得主线程不断的接受用户操作事件。
2. <strong>处理App的中各种事件</strong>，比如：触摸事件(Port源？)，定时器事件(Timer源)，Selector事件?
3. <strong>节省CPU资源,提高程序性能</strong>,因为runloop保证了线程在没有事件处理的时候可以休眠，大大提高了程序性能。

![runloop-image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runloop.jpg)

# 如何开启RunLoop?
1. 主线程Runloop:主线程runloop是在UIApplicationMain函数中启动的，主线程一启动会立刻创建一个runloop.
```php
int main(int argc, char * argv[]) {
	@autoreleasepool {
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
```
进入UIApplicationMain函数中：
```php
// If nil is specified for principalClassName, the value for NSPrincipalClass from the Info.plist is used. If there is no
// NSPrincipalClass key specified, the UIApplication class is used. The delegate class will be instantiated using init.
UIKIT_EXTERN int UIApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);
```
上面这个函数式返回值是一个Int值，我们可以对main函数做出修改：
```php
int main(int argc, char * argv[]) {
	@autoreleasepool {
		NSLog(@"begin");
		int re = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
		NSLog(@"end");
		return re;
	}
}
```
运行之后发现只打印”begin"；
> UIApplicationMain函数中开启了一个和主线程有关的runloop，导致UIApplicationMain函数不返回，一直运行；

```php
void CFRunLoopRun(void) {	/* DOES CALLOUT */
    int32_t result;
    do {
        result = CFRunLoopRunSpecific(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 1.0e10, false);
        CHECK_FOR_FORK();
    } while (kCFRunLoopRunStopped != result && kCFRunLoopRunFinished != result);
}
```
从CFRunloopRef源码中我们也可以看到确实是一个do-while循环。

# RunLoop对象
> 1. NSRunLoop对象 --> Fundation框架，基于CFRunLoopRef的封装；非线性安全的；
> 2. CFRunLoopRef对象 --> CoreFoundation;线程安全的；

#### 如何获取RunLoop对象
苹果没有提供创建runloop的方法；仅仅提供了获取runloop的方法：
```php
Foundation
[NSRunLoop CurrentRunLoop];//获取当前线程的Runloop
[NSRunLoop mainRunLoop]; // 获取主线程的RunLoop

CoreFoundation
CFRunLoopGetCurrent();
CFRunLoopGetMain();
```

# RunLoop和线程的关系
> 1. 线程和RunLoop是一一对应的；一个线程存在仅存在至多一个Runloop;
> 2. 线程RunLoop保持在一个全局的Dictionary中，@[key(线程)：value(RunLoop)]
> 3. 主线程的RunLoop是默认开启的，子线程RunLoop需要手动创建；
> 4. RunLoop在第一次获取时创建，在线程结束时销毁；

#### 源码验证
```php
//在线程中获取当前线程的runloop，会调用_CFRunLoopGet0
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CHECK_FOR_FORK();
    CFRunLoopRef rl = (CFRunLoopRef)_CFGetTSD(__CFTSDKeyRunLoop);
    if (rl) return rl;
    return _CFRunLoopGet0(pthread_self());
}

// should only be called by Foundation
// t==0 is a synonym for "main thread" that always works
// _CFRunLoopGet0内部实现
CF_EXPORT CFRunLoopRef _CFRunLoopGet0(pthread_t t) {
    //做个判断
    if (pthread_equal(t, kNilPthreadT)) {
	t = pthread_main_thread_np();
    }
    __CFSpinLock(&loopsLock);
    if (!__CFRunLoops) {
        __CFSpinUnlock(&loopsLock);
	CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
	//根据传入的如果是主线程，获取主线的runloop,app一旦启动走这里
	CFRunLoopRef mainLoop = __CFRunLoopCreate(pthread_main_thread_np());
	//把主线程存储到一个全局的Dictionary中
	CFDictionarySetValue(dict, pthreadPointer(pthread_main_thread_np()), mainLoop);
	if (!OSAtomicCompareAndSwapPtrBarrier(NULL, dict, (void * volatile *)&__CFRunLoops)) {
	    CFRelease(dict);
	}
	CFRelease(mainLoop);
        __CFSpinLock(&loopsLock);
    }
    // 当获取的不是主线程的时候，会先从字典中获取loop
    CFRunLoopRef loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
    __CFSpinUnlock(&loopsLock);
    if (!loop) {
    	//如果loop是空的，会创建一个新的，因此runloop是在第一次获取的时候创建的
	CFRunLoopRef newLoop = __CFRunLoopCreate(t);
        __CFSpinLock(&loopsLock);
	loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
	if (!loop) {
	//把runloop存储到全局Dictionary中
	    CFDictionarySetValue(__CFRunLoops, pthreadPointer(t), newLoop);
	    loop = newLoop;
	}
        // don't release run loops inside the loopsLock, because CFRunLoopDeallocate may end up taking it
        __CFSpinUnlock(&loopsLock);
	CFRelease(newLoop);
    }
    if (pthread_equal(t, pthread_self())) {
        _CFSetTSD(__CFTSDKeyRunLoop, (void *)loop, NULL);
        if (0 == _CFGetTSD(__CFTSDKeyRunLoopCntr)) {
            _CFSetTSD(__CFTSDKeyRunLoopCntr, (void *)(PTHREAD_DESTRUCTOR_ITERATIONS-1), (void (*)(void *))__CFFinalizeRunLoop);
        }
    }
    return loop;
}

```

# RunLoop结构分析
先来看下RunLoop在内存中是如何布局的：
<strong>__CFRunLoop</strong>
```php
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;			/* locked for accessing mode list */
    __CFPort _wakeUpPort;			// used for CFRunLoopWakeUp 
    Boolean _unused;
    volatile _per_run_data *_perRunData;              // reset for runs of the run loop
    pthread_t _pthread;
    uint32_t _winthread;
    CFMutableSetRef _commonModes;
    CFMutableSetRef _commonModeItems;
    CFRunLoopModeRef _currentMode;
    CFMutableSetRef _modes;
    struct _block_item *_blocks_head;
    struct _block_item *_blocks_tail;
    CFTypeRef _counterpart;
};
```
重点我们看这四个成员变量：
```php
CFMutableSetRef _commonModes;
CFMutableSetRef _commonModeItems;
CFRunLoopModeRef _currentMode;
CFMutableSetRef _modes;
```
而CFRunLoopModeRef都是指向__CFRunLoopMode结构体的指针：
<strong>__CFRunLoop</strong>
```php
typedef struct __CFRunLoopMode *CFRunLoopModeRef;
struct __CFRunLoopMode {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;	/* must have the run loop locked before locking this */
    CFStringRef _name;
    Boolean _stopped;
    char _padding[3];
    CFMutableSetRef _sources0;
    CFMutableSetRef _sources1;
    CFMutableArrayRef _observers;
    CFMutableArrayRef _timers;
    CFMutableDictionaryRef _portToV1SourceMap;
    __CFPortSet _portSet;
    CFIndex _observerMask;
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;
    dispatch_queue_t _queue;
    Boolean _timerFired; // set to true by the source when a timer has fired
    Boolean _dispatchTimerArmed;
#endif
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;
    Boolean _mkTimerArmed;
#endif
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;
    void (*_msgPump)(void);
#endif
    uint64_t _timerSoftDeadline; /* TSR */
    uint64_t _timerHardDeadline; /* TSR */
};
```
在mode结构中我们主要注意以下成员变量：
```php
CFMutableSetRef _sources0;
CFMutableSetRef _sources1;
CFMutableArrayRef _observers;
CFMutableArrayRef _timers;
```

![runloop-mode](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runloop-mode.png)

> <strong>总结：CFRunLoopModeRef代表RunLoop的运行模式，一个RunLoop包含若干的Mode，每个mode又包含若干的Source0/Source1/Timer/Observer,而runLoop只能选择其中一个mode座位currentMode </strong>

### Source0/Source1/Timers/Observers代表什么？

1. Source1: 基于Port的线程间通信
2. Source0: 触摸事件，PerformSelectors
断点验证：

```php
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	NSLog(@"touch screen");
}
```
通过在控制台输入<strong>bt</strong>查看完整的堆栈信息：
![Source0](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/source0.png)

同样我们验证下performSelector堆栈信息
```php
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	[self performSelectorOnMainThread:@selector(test) withObject:nil waitUntilDone:YES];
});
```
![Source0](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/source00.png)

3. Timers: 定时器，NSTimer
验证：
```php
[NSTimer scheduledTimerWithTimeInterval:3 repeats:NO block:^(NSTimer * _Nonnull timer) {
	NSLog(@"timer begin");
}];
```
![Timer](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/timer.png)

4. Observer: 监听器，用户监听RunLoop状态

# RunLoop相关类及作用
> 1. CFRunLoopRef - 获得当前RunLoop和主RunLoop
> 2. CFRunLoopModeRef - RunLoop 运行模式，只能选择一种，在不同模式中做不同的操作
> 3. CFRunLoopSourceRef - 事件源，输入源
> 4. CFRunLoopTimerRef - 定时器时间
> 5. CFRunLoopObserverRef - 观察者

#### CFRunLoopModeRef
1. 一个 RunLoop 包含若干个 Mode，每个Mode又包含若干个Source、Timer、Observer
2. 每次RunLoop启动时，只能指定其中一个 Mode，这个Mode被称作 CurrentMode
3. 如果需要切换Mode，只能退出RunLoop，再重新指定一个Mode进入，这样做主要是为了分隔开不同组的Source、Timer、Observer，让其互不影响
4. 如果Mode里没有任何Source0/Source1/Timer/Observer，RunLoop会立马退出
> 一种Mode中可以有多个Source(事件源，输入源，基于端口事件源例键盘触摸等) Observer(观察者，观察当前RunLoop运行状态) 和Timer(定时器事件源)。但是必须至少有一个Source或者Timer，因为如果Mode为空，RunLoop运行到空模式不会进行空转，就会立刻退出。

##### 系统默认注册的5个Mode:
```php
1. kCFRunLoopDefaultMode：App的默认Mode，通常主线程是在这个Mode下运行
2. UITrackingRunLoopMode：界面跟踪 Mode，用于 ScrollView 追踪触摸滑动，保证界面滑动时不受其他 Mode 影响
3. UIInitializationRunLoopMode: 在刚启动 App 时第进入的第一个 Mode，启动完成后就不再使用，会切换到kCFRunLoopDefaultMode
4. GSEventReceiveRunLoopMode: 接受系统事件的内部 Mode，通常用不到
5. kCFRunLoopCommonModes: 这是一个占位用的Mode，作为标记kCFRunLoopDefaultMode和UITrackingRunLoopMode用，并不是一种真正的Mode
```

##### Mode间的切换
Q: 当我们使用NSTimer每一段时间执行一些事情时滑动UIScrollView，NSTimer就会暂停，当我们停止滑动以后，NSTimer又会重新恢复的情况，我们通过一段代码来看一下:
```php
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(show) userInfo:nil repeats:YES];
    NSTimer *timer = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(show) userInfo:nil repeats:YES];
    // 加入到RunLoop中才可以运行
    // 1. 把定时器添加到RunLoop中，并且选择默认运行模式NSDefaultRunLoopMode = kCFRunLoopDefaultMode
    // [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    // 当textFiled滑动的时候，timer失效，停止滑动时，timer恢复
    // 原因：当textFiled滑动的时候，RunLoop的Mode会自动切换成UITrackingRunLoopMode模式，因此timer失效，当停止滑动，RunLoop又会切换回NSDefaultRunLoopMode模式，因此timer又会重新启动了
    
    // 2. 当我们将timer添加到UITrackingRunLoopMode模式中，此时只有我们在滑动textField时timer才会运行
    // [[NSRunLoop mainRunLoop] addTimer:timer forMode:UITrackingRunLoopMode];
    
    // 3. 那个如何让timer在两个模式下都可以运行呢？
    // 3.1 在两个模式下都添加timer 是可以的，但是timer添加了两次，并不是同一个timer
    // 3.2 使用站位的运行模式 NSRunLoopCommonModes标记，凡是被打上NSRunLoopCommonModes标记的都可以运行，下面两种模式被打上标签
    //0 : <CFString 0x10b7fe210 [0x10a8c7a40]>{contents = "UITrackingRunLoopMode"}
    //2 : <CFString 0x10a8e85e0 [0x10a8c7a40]>{contents = "kCFRunLoopDefaultMode"}
    // 因此也就是说如果我们使用NSRunLoopCommonModes，timer可以在UITrackingRunLoopMode，kCFRunLoopDefaultMode两种模式下运行
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    NSLog(@"%@",[NSRunLoop mainRunLoop]);
}
-(void)show
{
    NSLog(@"-------");
}

```
> 总结：想要保证Timer正常工作，就需要手动将Timer添加到commonMode中

```php

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    NSLog(@"%s",__func__);
    // performSelector默认是在default模式下运行，因此在滑动ScrollView时，图片不会加载
    // [self.imageView performSelector:@selector(setImage:) withObject:[UIImage imageNamed:@"abc"] afterDelay:2.0 ];
    // inModes: 传入Mode数组
    [self.imageView performSelector:@selector(setImage:) withObject:[UIImage imageNamed:@"abc"] afterDelay:2.0 inModes:@[NSDefaultRunLoopMode,UITrackingRunLoopMode]];
    
}
```
再看一个GCD的例子：
```php

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    //创建队列
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    //1.创建一个GCD定时器
    /*
     第一个参数:表明创建的是一个定时器
     第四个参数:队列
     */
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    // 需要对timer进行强引用，保证其不会被释放掉，才会按时调用block块
    // 局部变量，让指针强引用
    self.timer = timer;
    //2.设置定时器的开始时间,间隔时间,精准度
    /*
     第1个参数:要给哪个定时器设置
     第2个参数:开始时间
     第3个参数:间隔时间
     第4个参数:精准度 一般为0 在允许范围内增加误差可提高程序的性能
     GCD的单位是纳秒 所以要*NSEC_PER_SEC
     */
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    
    //3.设置定时器要执行的事情
    dispatch_source_set_event_handler(timer, ^{
        NSLog(@"---%@--",[NSThread currentThread]);
    });
    // 启动
    dispatch_resume(timer);
}

```
#### CFRunLoopSourceRef事件源（输入源）
Source分为两种:
1. Source0：非基于Port的 用于用户主动触发的事件（点击button 或点击屏幕）
2. Source1：基于Port的 通过内核和其他线程相互发送消息（与内核相关）

#### CFRunLoopObserverRef
CFRunLoopObserverRef是观察者，能够监听RunLoop的状态改变
```php
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
     //创建监听者
     /*
     第一个参数 CFAllocatorRef allocator：分配存储空间 CFAllocatorGetDefault()默认分配
     第二个参数 CFOptionFlags activities：要监听的状态 kCFRunLoopAllActivities 监听所有状态
     第三个参数 Boolean repeats：YES:持续监听 NO:不持续
     第四个参数 CFIndex order：优先级，一般填0即可
     第五个参数 ：回调 两个参数observer:监听者 activity:监听的事件
     */
     /*
     所有事件
     typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
     kCFRunLoopEntry = (1UL << 0),   //   即将进入RunLoop
     kCFRunLoopBeforeTimers = (1UL << 1), // 即将处理Timer
     kCFRunLoopBeforeSources = (1UL << 2), // 即将处理Source
     kCFRunLoopBeforeWaiting = (1UL << 5), //即将进入休眠
     kCFRunLoopAfterWaiting = (1UL << 6),// 刚从休眠中唤醒
     kCFRunLoopExit = (1UL << 7),// 即将退出RunLoop
     kCFRunLoopAllActivities = 0x0FFFFFFFU
     };
     */
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopEntry:
                NSLog(@"RunLoop进入");
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"RunLoop要处理Timers了");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"RunLoop要处理Sources了");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"RunLoop要休息了");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"RunLoop醒来了");
                break;
            case kCFRunLoopExit:
                NSLog(@"RunLoop退出了");
                break;
                
            default:
                break;
        }
    });
    
    // 给RunLoop添加监听者
    /*
     第一个参数 CFRunLoopRef rl：要监听哪个RunLoop,这里监听的是主线程的RunLoop
     第二个参数 CFRunLoopObserverRef observer 监听者
     第三个参数 CFStringRef mode 要监听RunLoop在哪种运行模式下的状态
     */
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
     /*
     CF的内存管理（Core Foundation）
     凡是带有Create、Copy、Retain等字眼的函数，创建出来的对象，都需要在最后做一次release
     GCD本来在iOS6.0之前也是需要我们释放的，6.0之后GCD已经纳入到了ARC中，所以我们不需要管了
     */
    CFRelease(observer);
}

```

#### RunLoop处理逻辑
![RunLoop-logic](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runloop-time.png)

#### RunLoop退出
1. 线程销毁，RunLoop退出
2. Mode中有一些Timer 、Source、 Observer，这些保证Mode不为空时保证RunLoop没有空转并且是在运行的，当Mode中为空的时候，RunLoop会立刻退出
3. 我们在启动RunLoop的时候可以设置什么时候停止
```php
[NSRunLoop currentRunLoop]runUntilDate:<#(nonnull NSDate *)#>
[NSRunLoop currentRunLoop]runMode:<#(nonnull NSString *)#> beforeDate:<#(nonnull NSDate *)#>
```

### RunLoop应用

#### 1. 常驻线程：我们知道，当子线程中的任务执行完毕之后就被销毁了，那么如果我们需要开启一个子线程，在程序运行过程中永远都存在，那么我们就会面临一个问题，如何让子线程永远活着，这时就要用到常驻线程：给子线程开启一个RunLoop
> 子线程执行完操作之后就会立即释放，即使我们使用强引用引用子线程使子线程不被释放，也不能给子线程再次添加操作，或者再次开启。
```php
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic,strong)NSThread *thread;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
   // 创建子线程并开启
    NSThread *thread = [[NSThread alloc]initWithTarget:self selector:@selector(show) object:nil];
    self.thread = thread;
    [thread start];
}
-(void)show
{
    // 注意：打印方法一定要在RunLoop创建开始运行之前，如果在RunLoop跑起来之后打印，RunLoop先运行起来，已经在跑圈了就出不来了，进入死循环也就无法执行后面的操作了。
    // 但是此时点击Button还是有操作的，因为Button是在RunLoop跑起来之后加入到子线程的，当Button加入到子线程RunLoop就会跑起来
    NSLog(@"%s",__func__);
    // 1.创建子线程相关的RunLoop，在子线程中创建即可，并且RunLoop中要至少有一个Timer 或 一个Source 保证RunLoop不会因为空转而退出，因此在创建的时候直接加入
    // 添加Source [NSMachPort port] 添加一个端口
    [[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    // 添加一个Timer
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(test) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];    
    //创建监听者
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopEntry:
                NSLog(@"RunLoop进入");
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"RunLoop要处理Timers了");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"RunLoop要处理Sources了");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"RunLoop要休息了");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"RunLoop醒来了");
                break;
            case kCFRunLoopExit:
                NSLog(@"RunLoop退出了");
                break;
            
            default:
                break;
        }
    });
    // 给RunLoop添加监听者
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    // 2.子线程需要开启RunLoop
    [[NSRunLoop currentRunLoop]run];
    CFRelease(observer);
}
- (IBAction)btnClick:(id)sender {
    [self performSelector:@selector(test) onThread:self.thread withObject:nil waitUntilDone:NO];
}
-(void)test
{
    NSLog(@"%@",[NSThread currentThread]);
}
@end
```

#### 2. 自动释放池

Timer和Source也是一些变量，需要占用一部分存储空间，所以要释放掉，如果不释放掉，就会一直积累，占用的内存也就越来越大，这显然不是我们想要的。
那么什么时候释放，怎么释放呢？
RunLoop内部有一个自动释放池，当RunLoop开启时，就会自动创建一个自动释放池，当RunLoop在休息之前会释放掉自动释放池的东西，然后重新创建一个新的空的自动释放池，当RunLoop被唤醒重新开始跑圈时，Timer,Source等新的事件就会放到新的自动释放池中，当RunLoop退出的时候也会被释放。
注意：只有主线程的RunLoop会默认启动。也就意味着会自动创建自动释放池，子线程需要在线程调度方法中手动添加自动释放池。


****

> 1. [Swift-Foundation](https://github.com/apple/swift-corelibs-foundation/)
> 2. [CFRunLoopRef源码](http://opensource.apple.com/tarballs/CF/)
> 3. [RunLoop](https://www.jianshu.com/p/de752066d0ad)
> 4. [blog.ibireme](https://blog.ibireme.com/2015/05/18/runloop/)
> 5. [runloop-apple](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16)
> 6. [iOS刨根问底-深入理解RunLoop](http://www.cnblogs.com/kenshincui/p/6823841.html)
