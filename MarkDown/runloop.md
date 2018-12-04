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























> 1. [Swift-Foundation](https://github.com/apple/swift-corelibs-foundation/)
> 2. [CFRunLoopRef源码](http://opensource.apple.com/tarballs/CF/)
> 3. [RunLoop](https://www.jianshu.com/p/de752066d0ad)
> 4. [blog.ibireme](https://blog.ibireme.com/2015/05/18/runloop/)
> 5. [runloop-apple](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16)
