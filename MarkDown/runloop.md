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



















> 1. [Swift-Foundation](https://github.com/apple/swift-corelibs-foundation/)
> 2. [CFRunLoopRef源码](http://opensource.apple.com/tarballs/CF/)
> 3. [RunLoop](https://www.jianshu.com/p/de752066d0ad)
> 4. [blog.ibireme](https://blog.ibireme.com/2015/05/18/runloop/)
> 5. [runloop-apple](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16)
> 6. [iOS刨根问底-深入理解RunLoop](http://www.cnblogs.com/kenshincui/p/6823841.html)
