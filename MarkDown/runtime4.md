## 1.super的本质

```php
#import "Student.h"
@implementation Student
- (instancetype)init
{
    if (self = [super init]) {
        NSLog(@"[self class] = %@", [self class]);
        NSLog(@"[self superclass] = %@", [self superclass]);
        NSLog(@"----------------");
        NSLog(@"[super class] = %@", [super class]);
        NSLog(@"[super superclass] = %@", [super superclass]);

    }
    return self;
}
@end
```

我们看戏打印结果：

```php
Runtime-super[6601:1536402] [self class] = Student
Runtime-super[6601:1536402] [self superclass] = Person
Runtime-super[6601:1536402] ----------------
Runtime-super[6601:1536402] [super class] = Student
Runtime-super[6601:1536402] [super superclass] = Person
```

上面代码中中无论是`self`还是`super`调用`class`或者`superClasss`结果都是相同的。

但是，结果是相同的，why?我们看下`super`关键字在调用方法的时候底层流程是如何的？

我们通过下面的代码来看`super`底层实现，为`person`提供`run`方法，`Student`类中重写`run`方法，方法内部调用`[super run]`，我们可以查看底层C++代码

```php
- (void) run
{
    [super run];
    NSLog(@"Student...");
}
```

```php
static void _I_Student_run(Student * self, SEL _cmd) {
    
    ((void (*)(__rw_objc_super *, SEL))(void *)objc_msgSendSuper)((__rw_objc_super){(id)self, (id)class_getSuperclass(objc_getClass("Student"))}, sel_registerName("run"));
    
    
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_jm_dztwxsdn7bvbz__xj2vlp8980000gn_T_Student_e677aa_mi_0);
}
```

上面的代码中，可以看出`[super run]`;转换为底层源码内部其实是调用的`objc_msgSendSuper`.

`objc_msgSendSuper`函数有两个参数：`__rw_objc_super`结构体和`sel_registerName("run")`方法名。

`__rw_objc_super`结构体内传入的参数是`self`和`class_getSuperClass(objc_getClass("Student"))`也就是`Student`的父类`Person`



我们找到`objc_msgSendSuper`函数内部进行查看：

```php
OBJC_EXPORT id _Nullable
objc_msgSendSuper(struct objc_super * _Nonnull super, SEL _Nonnull op, ...)
    OBJC_AVAILABLE(10.0, 2.0, 9.0, 1.0, 2.0);
```

我么可以发现`objc_msgSendSuper`中传入的结构体是`objc_super`,我们再查看`objc_super`结构体：

```php
// 精简后的objc_super结构体
struct objc_super {
    __unsafe_unretained _Nonnull id receiver; // 消息接受者
    __unsafe_unretained _Nonnull Class super_class; // 消息接受者的父类
    /* super_class is the first class to search */ 
    // 父类是第一个开始查找的类
};
```

从`objc_super`的结构体中发现`receiver`的消息接受者仍为`self`,`superClass`仅仅是告诉告知消息是从哪一个类开始查找而已，这里即从父类开始查找。

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime4-1.png)

从上面的图的分析中，我们知道 **super调用方法的消息接受者receiver仍然是self，只是从父类的类对象开始查找方法**。

从新回到这道题，我们看下`class`的底层实现：

```php
+ (Class)class {
    return self;
}

- (Class)class {
    return object_getClass(self);
}
```

⚠️class内部实现是根据消息接收者返回其对象的类对象，最后会找到基类的方法列表中，而`self`和`super`的区别仅仅是`self`从本类的类对象开始查找，`super`从父类的类对象开始查找，因此最终的结果都是一样的。

同时回到`run`方法内部，如果`super`不是从父类开始查找方法，那么就会调用方法本身造成循环调用而crash。



⚠️同理`superclass`底层实现和`class`类似：

```php
+ (Class)superclass {
    return self->superclass;
}

- (Class)superclass {
    return [self class]->superclass;
}
```

#### objc_msgSendSuper2 函数

将上面的代码转为C++不能说明`super`底层调用函数就是`objc_msgSendSuper`

其实super底层真正调用的函数式`objc_msgSendSuper2`,通过把`super`调用方法的汇编代码来验证：

```php
- (void)viewDidLoad {
    [super viewDidLoad];
}
```

通过打断点查看汇编调用栈：

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/huibian.png)

从上面的断点可以知道`super`底层调用的是`objc_msgSendSuper2`函数，我们来到源码中查找下`objc_msgSendSuper2`

```php
NTRY _objc_msgSendSuper2
UNWIND _objc_msgSendSuper2, NoFrame
MESSENGER_START

ldp x0, x16, [x0]       // x0 = real receiver, x16 = class
ldr x16, [x16, #SUPERCLASS] // x16 = class->superclass
CacheLookup NORMAL

END_ENTRY _objc_msgSendSuper2
```

发现函数内部是通过`class->superclass`来获取父类，并不是直接传入父类。

**其实_objc_msgSendSuper2传入的是结构体objc_super2**

```php
struct objc_super2 {
    id receiver;
    Class current_class;
};
```

`objc_super2`中除了消息接收者`receiver`,另一个成员变量`current_class`也就是当前类。

因此`objc_msgSendSuper2`函数内部传入是当前类对象，然后在函数内部获取当前类对象的父类，然后从父类开始查找。



## 2. isKindOfClass 和 isMemberOfClass

首先来看下`isKindOfClass`和`isMemberOfClass`的对象方法底层实现：

```php
- (BOOL)isMemberOfClass:(Class)cls {
   // 直接获取实例类对象并判断是否等于传入的类对象
    return [self class] == cls;
}

- (BOOL)isKindOfClass:(Class)cls {
   // 向上查询，如果找到父类对象等于传入的类对象则返回YES
   // 直到基类还不相等则返回NO
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}
```

`isKindOfClass`和`isMemberOfClass`的类方法实现：

```php
// 判断元类对象是否等于传入的元类元类对象
// 此时self是类对象 object_getClass((id)self)就是元类
+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

// 向上查找，判断元类对象是否等于传入的元类对象
// 如果找到基类还不相等则返回NO
// 注意：这里会找到基类
+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}
```

`isMemberOfClass`**直接判断左边的类对象是不是等于右边的类对象**

`isKindOfClass`**判断左边或者左边的父类对象是否刚好等于右边类型**

⚠️**类方法内部是获取其元类对象进行对比**

下面练习：

```php
NSLog(@"%d",[Person isKindOfClass: [Person class]]);
NSLog(@"%d",[Person isKindOfClass: object_getClass([Person class])]);
NSLog(@"%d",[Person isKindOfClass: [NSObject class]]);

// 输出内容
Runtime-super[46993:5195901] 0
Runtime-super[46993:5195901] 1
Runtime-super[46993:5195901] 1
```

`第一个为0：`上面知道类方法里面是获取self的元类对象和传入的参数进行的比较，但是第一个我们传入的是类对象，因此是0.

`第二个为1：`因为我们传入的是Person类对象，因此为1；

`第三个为1：`我们发现传入的并不是元类对象，但是返回1，**是由于 基元类对象的superClass指针指向的是基类对象的**

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-2.png)

那么`Person元类`通过`superclass`指针一直找到基元类，还是不相等，此时再次通过`superclass`指针来到基类，那么此时发现相等就会返回YES了。

## 3.面试题

看看下面的结果输出：

```php
/ Person.h
#import <Foundation/Foundation.h>
@interface Person : NSObject
@property (nonatomic, strong) NSString *name;
- (void)test;
@end

// Person.m
#import "Person.h"
@implementation Person
- (void)test
{
    NSLog(@"test print name is : %@", self.name);
}
@end

// ViewController.m
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    id cls = [Person class];
    void *obj = &cls;
    [(__bridge id)obj test];
    
    Person *person = [[Person alloc] init];
    [person test];
}
```

```php
Runtime面试题[15842:2579705] test print name is : <ViewController: 0x7f95514077a0>
Runtime面试题[15842:2579705] test print name is : (null)
```

结果是不是很出乎意料：

为什么objc的输出结果是`<ViewController: 0x7f95514077a0>`?

首先通过一张图看一下两种调用方法的内存信息。

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-3.png)

#### 1.objc为什么可以正常调用方法

之前我们知道，`person`调用方法的时候可以通过`isa`指针找到类对象进而找到方法进行调用。

而`person`实例对象内实际上是取最前面的8个字节空间也就是`isa`并通过计算得出类对象地址。

通过上图我们可以知道，`obj`在调用`test`方法的是时候，也是通过其内存地址找到`cls`,而`cls`中取出的最前面的8个字节空间的刚好就是`Person`类对象的地址。



#### 2.为什么`self.name`打印内容是`viewcontroller`对象

问题出在`[super viewDidLoad]`这段代码中，在上面的代码中，通过对`super`本质的分析我们知道`super`内部调用`objc_msgSendSuper2`.

`objc_msgSendSuper2`函数会传入两个参数，`objc_super2`结构体和`SEL`并且`objc_super2`结构体内有两个成员变量消息接受者和其父类：

```php
struct objc_super2 {
    id receiver; // 消息接受者
    Class current_class; // 当前类
};
```

因此从上面的分析知道，在`objc_super2`内部结构如下：

```php
struct objc_super = {
    self,
    [ViewController Class]
};
```

在`objc_msgSendSuper2`函数调用前，会先创建局部变量`objc_super2`结构体用于传递给`objc_msgSendSuper2`参数。

#### 3.局部变量由高地址向低地址分配在栈空间

我们知道局部变量存储在栈空间的，并且是由高地址向低地址有序存储。

我们通过下面验证：

```php
long long a = 1;
long long b = 2;
long long c = 3;
NSLog(@"%p %p %p", &a,&b,&c);
// 打印内容
0x7ffeefbff5a8 0x7ffeefbff5a0 0x7ffeefbff598
```

```php
上面的代码可以证明，**局部变量在栈空间是由高地址向低地址连续存储的**
```

上面的面试代码中，包含的局部变量由`objc_super2` `cls` `obj` 下面是结构：

![obj](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-4.png)

上面代码我们知道，`person`实例对象调用方法的时候，会取实例变量的前8个字节空间也就是`isa`来找到类对象地址。那么当访问实例变量的时候，就会跳过`isa`的前8个字节前往下面查找实例变量。

那么当`obj`在调用`test`方法的时候，同样找到`cls`中取出前8个字节，也就是`person`类对象的内存地址，那么当访问实例变量的 `_name` 的时候，会继续向高地址存储空间查找，，此时就会找到`objc_super`结构体，从取出8个内存空间也就是`self`，因此此时访问到`self.mame`就是`viewController`对象。

当访问成员变量的`_name`的时候，`test`函数中的self也就是调用者，即`obj`，那么`self.name`就是通过obj查找`_name`,跳过cls的8个字节，在取8个字节当然就是`ViewController`对象。

因此上面的代码中`cls`就相当于isa,`isa`下面的8个字节空间就相当于`_name`成员变量。因此成员变量`_name`访问到的值就是`cls`地址后高地址取8给字节空间存储的值。



我们在`cls`后高地址中添加一个`string`,那么此时`cls`下面的高地址位就是`string`了：

```php
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *string = @"string";
    
    id cls = [Person class];
    void *obj = &cls;
    [(__bridge id)obj test];
    
    Person *person = [[Person alloc] init];
    [person test];
}
```

下面是示意图：

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-5.png)

此时我们再访问`_name`成员变量的时候，越过`cls`内存往高处内存地址寻找就会找到`string`,此时拿到的成员变量就是`string`了。

来看下打印的结果：

```php
Runtime面试题[16887:2829028] test print name is : string
Runtime面试题[16887:2829028] test print name is : (null)
```

再看一个int类型的：

```php
- (void)viewDidLoad {
    [super viewDidLoad];

    int a = 3;
    
    id cls = [Person class];
    void *obj = &cls;
    [(__bridge id)obj test];
    
    Person *person = [[Person alloc] init];
    [person test];
}
// 程序crash，坏地址访问
```

我们发现程序因为坏地址访问而crash，此时局部变量内存结构如下图所示:

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-6.png)

当需要访问`_name`成员变量的时候，会在`cls`后高地址为查找8位的字节空间，而我们知道`int`占4位字节，那么此时8位的内存空间同时占据`int`数据及`objc_super`结构体内，因此就会造成坏地址访问而crash。

我们添加新的成员变量进行访问:

```php
// Person.h
#import <Foundation/Foundation.h>
@interface Person : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *nickName;
- (void)test;
@end
------------
// Person.m
#import "Person.h"
@implementation Person
- (void)test
{
    NSLog(@"test print name is : %@", self.nickName);
}
@end
--------
//  ViewController.m
- (void)viewDidLoad {
    [super viewDidLoad];

    NSObject *obj1 = [[NSObject alloc] init];
    
    id cls = [Person class];
    void *obj = &cls;
    [(__bridge id)obj test];
    
    Person *person = [[Person alloc] init];
    [person test];
}
```

打印结果：

```php
// 打印内容
// Runtime面试题[17272:2914887] test print name is : <ViewController: 0x7ffc6010af50>
// Runtime面试题[17272:2914887] test print name is : (null)
```

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-7.png)

首先通过`obj`找到`cls`，`cls`找到类对象进行方法调用，此时在访问`nickName`时，`obj`查找成员变量，首先跳过8个字节的`cls`，之后跳过`name`所占的8个字节空间，最终再取8个字节空间取出其中的值作为成员变量的值，那么此时也就是`self`了。

总结：这道面试题虽然很无厘头，让人感觉无从下手但是考察的内容非常多。  
**1. super的底层本质为调用`objc_msgSendSuper2`函数，传入`objc_super2`结构体，结构体内部存储消息接受者和当前类，用来告知系统方法查找从父类开始。**

**2. 局部变量分配在栈空间，并且从高地址向低地址连续分配。先创建的局部变量分配在高地址，后续创建的局部变量连续分配在较低地址。**

**3. 方法调用的消息机制，通过isa指针找到类对象进行消息发送。**

**4. 指针存储的是实例变量的首字节地址，上述例子中`person`指针存储的其实就是实例变量内部的`isa`指针的地址。**

**5. 访问成员变量的本质，找到成员变量的地址，按照成员变量所占的字节数，取出地址中存储的成员变量的值。**



#### 验证objc_msgSendSuper2内传入的结构体参数

我们使用以下代码来验证上文中遗留的问题:

```php
- (void)viewDidLoad {
    [super viewDidLoad];
    id cls = [Person class];
    void *obj = &cls;
    [(__bridge id)obj test];
}
```

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-8.png)

通过上面对面试题的分析，我们现在想要验证`objc_msgSendSuper2`函数内传入的结构体参数，只需要拿到`cls`的地址，然后向后移8个地址就可以获取到`objc_super`结构体内的`self`，在向后移8个地址就是`current_class`的内存地址。通过打印`current_class`的内容，就可以知道传入`objc_msgSendSuper2`函数内部的是当前类对象还是父类对象了。

我们来证明他是`UIViewController`还是`ViewController`即可

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rumtime4-8.png)

通过上图可以发现，最终打印的内容确实为当前类对象。  
**因此`objc_msgSendSuper2`函数内部其实传入的是当前类对象，并且在函数内部获取其父类，告知系统从父类方法开始查找的。**

### Runtime API

```php
// Person类继承自NSObject，包含run方法
@interface Person : NSObject
@property (nonatomic, strong) NSString *name;
- (void)run;
@end

#import "Person.h"
@implementation Person
- (void)run
{
    NSLog(@"%s",__func__);
}
@end

// Car类继承自NSObejct，包含run方法
#import "Car.h"
@implementation Car
- (void)run
{
    NSLog(@"%s",__func__);
}
@end
```

#### 类相关API

```php
1. 动态创建一个类（参数：父类，类名，额外的内存空间）
Class objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)

2. 注册一个类（要在类注册之前添加成员变量）
void objc_registerClassPair(Class cls) 

3. 销毁一个类
void objc_disposeClassPair(Class cls)

示例：
void run(id self , SEL _cmd) {
    NSLog(@"%@ - %@", self,NSStringFromSelector(_cmd));
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // 创建类 superclass:继承自哪个类 name:类名 size_t:格外的大小，创建类是否需要扩充空间
        // 返回一个类对象
        Class newClass = objc_allocateClassPair([NSObject class], "Student", 0);
        
        // 添加成员变量 
        // cls:添加成员变量的类 name:成员变量的名字 size:占据多少字节 alignment:内存对齐，最好写1 types:类型，int类型就是@encode(int) 也就是i
        class_addIvar(newClass, "_age", 4, 1, @encode(int));
        class_addIvar(newClass, "_height", 4, 1, @encode(float));
        
        // 添加方法
        class_addMethod(newClass, @selector(run), (IMP)run, "v@:");
        
        // 注册类
        objc_registerClassPair(newClass);
        
        // 创建实例对象
        id student = [[newClass alloc] init];
    
        // 通过KVC访问
        [student setValue:@10 forKey:@"_age"];
        [student setValue:@180.5 forKey:@"_height"];
        
        // 获取成员变量
        NSLog(@"_age = %@ , _height = %@",[student valueForKey:@"_age"], [student valueForKey:@"_height"]);
        
        // 获取类的占用空间
        NSLog(@"类对象占用空间%zd", class_getInstanceSize(newClass));
        
        // 调用动态添加的方法
        [student run];
        
    }
    return 0;
}

// 打印内容
// Runtime应用[25605:4723961] _age = 10 , _height = 180.5
// Runtime应用[25605:4723961] 类对象占用空间16
// Runtime应用[25605:4723961] <Student: 0x10072e420> - run

注意
类一旦注册完毕，就相当于类对象和元类对象里面的结构就已经创建好了。
因此必须在注册类之前，添加成员变量。方法可以在注册之后再添加，因为方法是可以动态添加的。
创建的类如果不需要使用了 ，需要释放类。

4. 获取isa指向的Class，如果将类对象传入获取的就是元类对象，如果是实例对象则为类对象
Class object_getClass(id obj)

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *person = [[Person alloc] init];
        NSLog(@"%p,%p,%p",object_getClass(person), [Person class],
              object_getClass([Person class]));
    }
    return 0;
}
// 打印内容
Runtime应用[21115:3807804] 0x100001298,0x100001298,0x100001270

5. 设置isa指向的Class，可以动态的修改类型。例如修改了person对象的类型，也就是说修改了person对象的isa指针的指向，中途让对象去调用其他类的同名方法。
Class object_setClass(id obj, Class cls)

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *person = [[Person alloc] init];
        [person run];
        
        object_setClass(person, [Car class]);
        [person run];
    }
    return 0;
}
// 打印内容
Runtime应用[21147:3815155] -[Person run]
Runtime应用[21147:3815155] -[Car run]
最终其实调用了car的run方法

6. 用于判断一个OC对象是否为Class
BOOL object_isClass(id obj)

// 判断OC对象是实例对象还是类对象
NSLog(@"%d",object_isClass(person)); // 0
NSLog(@"%d",object_isClass([person class])); // 1
NSLog(@"%d",object_isClass(object_getClass([person class]))); // 1 
// 元类对象也是特殊的类对象

7. 判断一个Class是否为元类
BOOL class_isMetaClass(Class cls)
8. 获取类对象父类
Class class_getSuperclass(Class cls)
```

### 成员变量相关API

```php
1. 获取一个实例变量信息，描述信息变量的名字，占用多少字节等
Ivar class_getInstanceVariable(Class cls, const char *name)

2. 拷贝实例变量列表（最后需要调用free释放）
Ivar *class_copyIvarList(Class cls, unsigned int *outCount)

3. 设置和获取成员变量的值
void object_setIvar(id obj, Ivar ivar, id value)
id object_getIvar(id obj, Ivar ivar)

4. 动态添加成员变量（已经注册的类是不能动态添加成员变量的）
BOOL class_addIvar(Class cls, const char * name, size_t size, uint8_t alignment, const char * types)

5. 获取成员变量的相关信息，传入成员变量信息，返回C语言字符串
const char *ivar_getName(Ivar v)
6. 获取成员变量的编码，types
const char *ivar_getTypeEncoding(Ivar v)

示例：
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // 获取成员变量的信息
        Ivar nameIvar = class_getInstanceVariable([Person class], "_name");
        // 获取成员变量的名字和编码
        NSLog(@"%s, %s", ivar_getName(nameIvar), ivar_getTypeEncoding(nameIvar));
        
        Person *person = [[Person alloc] init];
        // 设置和获取成员变量的值
        object_setIvar(person, nameIvar, @"xx_cc");
        // 获取成员变量的值
        object_getIvar(person, nameIvar);
        NSLog(@"%@", object_getIvar(person, nameIvar));
        NSLog(@"%@", person.name);
        
        // 拷贝实例变量列表
        unsigned int count ;
        Ivar *ivars = class_copyIvarList([Person class], &count);

        for (int i = 0; i < count; i ++) {
            // 取出成员变量
            Ivar ivar = ivars[i];
            NSLog(@"%s, %s", ivar_getName(ivar), ivar_getTypeEncoding(ivar));
        }
        
        free(ivars);

    }
    return 0;
}

// 打印内容
// Runtime应用[25783:4778679] _name, @"NSString"
// Runtime应用[25783:4778679] xx_cc
// Runtime应用[25783:4778679] xx_cc
// Runtime应用[25783:4778679] _name, @"NSString"
```

#### 属性相关API

```php
1. 获取一个属性
objc_property_t class_getProperty(Class cls, const char *name)

2. 拷贝属性列表（最后需要调用free释放）
objc_property_t *class_copyPropertyList(Class cls, unsigned int *outCount)

3. 动态添加属性
BOOL class_addProperty(Class cls, const char *name, const objc_property_attribute_t *attributes,
                  unsigned int attributeCount)

4. 动态替换属性
void class_replaceProperty(Class cls, const char *name, const objc_property_attribute_t *attributes,
                      unsigned int attributeCount)

5. 获取属性的一些信息
const char *property_getName(objc_property_t property)
const char *property_getAttributes(objc_property_t property)
```

#### 方法相关API

```php
1. 获得一个实例方法、类方法
Method class_getInstanceMethod(Class cls, SEL name)
Method class_getClassMethod(Class cls, SEL name)

2. 方法实现相关操作
IMP class_getMethodImplementation(Class cls, SEL name) 
IMP method_setImplementation(Method m, IMP imp)
void method_exchangeImplementations(Method m1, Method m2) 

3. 拷贝方法列表（最后需要调用free释放）
Method *class_copyMethodList(Class cls, unsigned int *outCount)

4. 动态添加方法
BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types)

5. 动态替换方法
IMP class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)

6. 获取方法的相关信息（带有copy的需要调用free去释放）
SEL method_getName(Method m)
IMP method_getImplementation(Method m)
const char *method_getTypeEncoding(Method m)
unsigned int method_getNumberOfArguments(Method m)
char *method_copyReturnType(Method m)
char *method_copyArgumentType(Method m, unsigned int index)

7. 选择器相关
const char *sel_getName(SEL sel)
SEL sel_registerName(const char *str)

8. 用block作为方法实现
IMP imp_implementationWithBlock(id block)
id imp_getBlock(IMP anImp)
BOOL imp_removeBlock(IMP anImp)
```


