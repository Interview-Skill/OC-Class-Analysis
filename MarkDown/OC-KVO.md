# KVO底层探究
### How to Use KVO?
```php
KVOPerson *kvoPerson1 = [[KVOPerson alloc] init];
KVOPerson *kvoPerson2 = [[KVOPerson alloc] init];
kvoPerson1.age = 1;
kvoPerson2.age = 2;

[kvoPerson1 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
kvoPerson1.age = 10;
kvoPerson2.age = 12;
//现在你需要实现delegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	NSLog(@"receive %@", change);
}
```
> 思考问题：<br>
iOS用什么方式实现对一个对象的KVO？（KVO的本质是什么？）<br>
如何手动触发KVO?<br>

### 探究KVO底层实现原理
> 从代码中可以看到，只要属性值发生变化，就会触发我们的监听回调！<br>
即使我们重写age属性值，监听回调也可以正常运行。

### KVO底层实现分析

通过对上面的代码，我们分析发现kvoPerson2在添加kvo之后发生了变化，我们通过断点来查看这两个对象的isa即类对象，根据一个类的类对象唯一性，kvoPerson1 和kvoPerson2的类对象
应该一致：
但是😲😲😲😲：
![kvo-isa](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/kvo-isa.png)
从上图的打印我们可以发现添加KVO之后，kvoPerson1的isa指向了一个新的类对象NSKVONotifying_KVOPerson,这个类继承自KVOPerson类；所以当你使用kvoPerson1实例对象调用setAge方法时，会先根据isa指针找到新的类对象NSKVONotifying_KVOPerson,并且**重写了这个类的setAge方法**
![not-use-kvo](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/kvo-setage-before.png)
添加KVO之后isa指针的指向：
![use-kvo](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/kvo-setage.png)

> NSKVONotifyin_Person中的setage方法中其实调用了 Fundation框架中C语言函数 _NSsetIntValueAndNotify，_NSsetIntValueAndNotify内部做的操作相当于，首先调用willChangeValueForKey 将要改变方法，之后调用父类的setage方法对成员变量赋值，最后调用didChangeValueForKey已经改变方法。didChangeValueForKey中会调用监听器的监听方法，最终来到监听者的observeValueForKeyPath方法中。

### 验证KVO底层实现

###### 通过打印方法实现的地址来看一下kvoPerson1和kvoPerson2的setage的方法实现的地址在添加KVO前后有什么变化。
```php
// 通过methodForSelector找到方法实现的地址
NSLog(@"添加KVO监听之前 - p1 = %p, p2 = %p", [kvoPerson1 methodForSelector: @selector(setAge:)],[kvoPerson2 methodForSelector: @selector(setAge:)]);
	
NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
[kvoPerson1 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];

NSLog(@"添加KVO监听之后 - p1 = %p, p2 = %p", [kvoPerson1 methodForSelector: @selector(setAge:)],[kvoPerson2 methodForSelector: @selector(setAge:)]);
```
![set-age-method](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/setage.png)
验证了kvoPerson1的setAge方法的实现由Person类方法中的setAge方法转换为了C语言的Foundation框架的_NSsetIntValueAndNotify函数
> Foundation框架中会根据属性的类型，调用不同的方法。例如我们之前定义的int类型的age属性，那么我们看到Foundation框架中调用的_NSsetIntValueAndNotify函数。那么我们把age的属性类型变为double重新打印一遍

```php
2018-12-04 14:49:28.250496+0800 iOS底层原理总结[20413:1682945] 添加KVO监听之前 - p1 = 0x104fdca70, p2 = 0x104fdca70
2018-12-04 14:49:31.316144+0800 iOS底层原理总结[20413:1682945] 添加KVO监听之后 - p1 = 0x105337d7c, p2 = 0x104fdca70
(lldb) p (IMP)0x105337d7c
(IMP) $0 = 0x0000000105337d7c (Foundation`_NSSetDoubleValueAndNotify)
(lldb) p (IMP)0x104fdca70
(IMP) $1 = 0x0000000104fdca70 (iOS底层原理总结`-[KVOPerson setAge:] at KVOPerson.h:15)
(lldb) 
```
所以我们可以推测Foundation框架中还有很多例如_NSSetBoolValueAndNotify、_NSSetCharValueAndNotify、_NSSetFloatValueAndNotify、_NSSetLongValueAndNotify等等函数；


