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






















