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

### ‼️NSKVONotifyin_Person内部结构
1.NSKVONotifyin_Person作为Person的子类，其superclass指针指向Person类，
2.NSKVONotifyin_Person内部一定对setAge方法做了单独的实现，那么NSKVONotifyin_Person同Person类的差别可能就在于其内存储的对象方法及实现不同。
通过runtime分别打印Person类对象和NSKVONotifyin_Person类对象内存储的对象方法
```php
- (void)viewDidLoad {
    [super viewDidLoad];

    Person *p1 = [[Person alloc] init];
    p1.age = 1.0;
    Person *p2 = [[Person alloc] init];
    p1.age = 2.0;
    // self 监听 p1的 age属性
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    [p1 addObserver:self forKeyPath:@"age" options:options context:nil];

    [self printMethods: object_getClass(p2)];
    [self printMethods: object_getClass(p1)];

    [p1 removeObserver:self forKeyPath:@"age"];
}

- (void) printMethods:(Class)cls
{
    unsigned int count ;
    Method *methods = class_copyMethodList(cls, &count);
    NSMutableString *methodNames = [NSMutableString string];
    [methodNames appendFormat:@"%@ - ", cls];
    
    for (int i = 0 ; i < count; i++) {
        Method method = methods[i];
        NSString *methodName  = NSStringFromSelector(method_getName(method));
        
        [methodNames appendString: methodName];
        [methodNames appendString:@" "];
        
    }
    
    NSLog(@"%@",methodNames);
    free(methods);
}

```
```php
2018-12-04 15:09:02.860320+0800 iOS底层原理总结[32970:1725940] NSKVONotifying_KVOPerson - setAge:--- class--- dealloc--- _isKVOA---
2018-12-04 15:09:03.697160+0800 iOS底层原理总结[32970:1725940] KVOPerson - address--- .cxx_destruct--- setAddress:--- setAge:--- age---
```
通过上述代码我们发现NSKVONotifyin_Person中有4个对象方法。分别为setAge: class dealloc _isKVOA，那么至此我们可以画出NSKVONotifyin_Person的内存结构以及方法调用顺序。

添加KVO之后isa指针的指向：
![use-kvo](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/kvo-setage.png)
‼️1. 重写了setAge方法
‼️2. 重写了class方法
NSKVONotifyin_Person重写class方法是为了隐藏NSKVONotifyin_Person。不被外界所看到。我们在p1添加过KVO监听之后，分别打印p1和p2对象的class可以发现他们都返回Person。如果NSKVONotifyin_Person不重写class方法，那么当对象要调用class对象方法的时候就会一直向上找来到nsobject，而nsobect的class的实现大致为返回自己isa指向的类，返回p1的isa指向的类那么打印出来的类就是NSKVONotifyin_Person
猜测NSKVONotifyin_Person内重写的class内部实现大致为：
```php
- (Class) class {
     // 得到类对象，在找到类对象父类
     return class_getSuperclass(object_getClass(self));
}
```
#### didChangeValueForKey:内部会调用observer的observeValueForKeyPath:ofObject:change:context:方法

我们通过重写Person的willChangeValueForKey 和didChangeValueForKey来验证在didChangeValueForKey内部调用observer的方法；

```php
- (void)setAge:(int)age
{
    NSLog(@"setAge:");
    _age = age;
}
- (void)willChangeValueForKey:(NSString *)key
{
    NSLog(@"willChangeValueForKey: - begin");
    [super willChangeValueForKey:key];
    NSLog(@"willChangeValueForKey: - end");
}
- (void)didChangeValueForKey:(NSString *)key
{
    NSLog(@"didChangeValueForKey: - begin");
    [super didChangeValueForKey:key];
    NSLog(@"didChangeValueForKey: - end");
}
```
## ‼️总结：

1. iOS用什么方式实现对一个对象的KVO？（KVO的本质是什么？）
答. 当一个对象使用了KVO监听，iOS系统会修改这个对象的isa指针，改为指向一个全新的通过Runtime动态创建的子类，子类拥有自己的set方法实现，set方法实现内部会顺序调用willChangeValueForKey方法、原来的setter方法实现、didChangeValueForKey方法，而didChangeValueForKey方法内部又会调用监听器的observeValueForKeyPath:ofObject:change:context:监听方法。

2. 如何手动触发KVO？
答. 被监听的属性的值被修改时，就会自动触发KVO。如果想要手动触发KVO，则需要我们自己调用willChangeValueForKey和didChangeValueForKey方法即可在不改变属性值的情况下手动触发KVO，并且这两个方法缺一不可。
