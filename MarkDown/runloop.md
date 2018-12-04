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
1. <strong>保证线程持续运行不退出<strong>:我们程序一旦启动，就会开一个主线程，同时会创建主线程对应的<strong>RunLoop<strong>,runloop保证了主线不会退出
，同时使得主线程不断的接受用户操作事件。
2. <strong>处理App的中各种事件<strong>，比如：触摸事件(Port源？)，定时器事件(Timer源)，Selector事件?
3. <strong>节省CPU资源,提高程序性能<strong>,因为runloop保证了线程在没有事件处理的时候可以休眠，大大提高了程序性能。
![runloop-image]()






















> 1. [Swift-Foundation](https://github.com/apple/swift-corelibs-foundation/)
> 2. [CFRunLoopRef源码](http://opensource.apple.com/tarballs/CF/)
> 3. [RunLoop](https://www.jianshu.com/p/de752066d0ad)
> 4. [blog.ibireme](https://blog.ibireme.com/2015/05/18/runloop/)
> 5. [runloop-apple](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16)
