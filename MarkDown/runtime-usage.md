## 一、Runtime简介

Runtime就是运行机制，OC就是运行时机制；对于C语言，函数在编译的时候就决定了调用哪个函数，如果调未实现的函数就会报错。但是OC属于动态调用过程，在编译的时候并不会决定真正的调用哪个函数，只有在真正运行的时候才会根据函数的名称找到函数对应的实现来调用，在编译阶段，OC可以调用任何函数，即使这个函数没有实现，只要声明了就可以。

## 二、Runtime消息机制

消息机制是运行时里面最重要的机制，OC可以调用任何方法的调用，本质上都是发送消息。使用运行时,发送消息需要导入`<objc/message.h>`框架。⚠️在xcode5之后，苹果不建议使用底层方法，如果需要使用运行时，需要关闭严格检查`objc_msgSend`，在`buildSetting`中搜索`msg`设置为NO.

实例方法底层调用：

```php
Person *p = [[Person alloc] init];
[p eat];
// 底层会转化成
//SEL：方法编号，根据方法编号就可以找到对应方法的实现。
[p performSelector:@selector(eat)];
//performSelector本质即为运行时，发送消息，谁做事情就调用谁 
objc_msgSend(p, @selector(eat));
// 带参数
objc_msgSend(p, @selector(eat:),10);
```

类方法底层调用：

```php
// 本质是会将类名转化成类对象，初始化方法其实是在创建类对象。
[Person eat];
// Person只是表示一个类名，并不是一个真实的对象。只要是方法必须要对象去调用。
// RunTime 调用类方法同样，类方法也是类对象去调用，所以需要获取类对象，然后使用类对象去调用方法。
Class personclass = [Persion class];
[[Persion class] performSelector:@selector(eat)];
// 类对象发送消息
objc_msgSend(personclass, @selector(eat));
```

#### 1.SEL是一个方法选择器

SEL的主要作用就是快速的通过方法名字查找对应方法的函数指针，然后调用函数实现，SEL本身是一个`Int`类型的指针，地址中存放着方法的名字。

**在一个类中，每个方法都有唯一对应的`SEL`,即使参数类型不同，对应的SEL也是相同的**

#### 2.运行时发送消息的底层实现

每一个类都有一个方法列表`Method-list`,保存了这个类里面所有的方法，根据`SEL`传入的`hash`值找到方法，相当于映射。

![rs](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rs-1.png)

#### 3.如何动态查找方法实现

任何类都继承自`NSObject`，其有一个类型为`Class`的`isa`指针：

```php
typedef struct objc_class *Class;
@interface NSObject <NSObject> {
    Class isa  OBJC_ISA_AVAILABILITY;
}
```

```php
struct objc_class {
  Class isa; // 指向metaclass

  Class super_class ; // 指向其父类
  const char *name ; // 类名
  long version ; // 类的版本信息，初始化默认为0，可以通过runtime函数class_setVersion和class_getVersion进行修改、读取
  long info; // 一些标识信息,如CLS_CLASS (0x1L) 表示该类为普通 class ，其中包含对象方法和成员变量;CLS_META (0x2L) 表示该类为 metaclass，其中包含类方法;
  long instance_size ; // 该类的实例变量大小(包括从父类继承下来的实例变量);
  struct objc_ivar_list *ivars; // 用于存储每个成员变量的地址
  struct objc_method_list **methodLists ; // 与 info 的一些标志位有关,如CLS_CLASS (0x1L),则存储对象方法，如CLS_META (0x2L)，则存储类方法;
  struct objc_cache *cache; // 指向最近使用的方法的指针，用于提升效率；
  struct objc_protocol_list *protocols; // 存储该类遵守的协议
}
```

1. 实例方法`[p eat]`；底层调用`[p performSelector:@selector(eat)]`方法，编译器将代码编译为cpp:`objc_msgSend(p, @selector(eat))`

2. 在`objc_msgSend`中，首先调用`p`的`isa`指针找到`p`对于的`class`.在`class`中先去cache中通过`SEL`查找对应的函数`method`,如果找到就直接执行。

3. 如果`cache`中没有，再去`methodList`中查找，如果找到，会将method进行缓存，方便下次调用。

4. 如果还没有找到，则沿着`superclass`查找。

5. 还没有的话，会调用动态添加方法查看有没有弥补

6. 动态添加方法没有实现,会进行消息转发。

7. 消息转发没有实现，最后会crash。

## 3、Runtime进行方法交换

**场景：系统自带的方法不够使用时，需要对系统方法进行扩展，并且保持原有的功能，可以使用runtime进行方法交换**

下面实现`image`添加图片的时候，自动判断图片是否存在，如果不存在提示为空：

#### 1）使用分类：

```php
+ (nullable UIImage *)xx_ccimageNamed:(NSString *)name
{
    // 加载图片    如果图片不存在则提醒或发出异常
   UIImage *image = [UIImage imageNamed:name];
    if (image == nil) {
        NSLog(@"图片不存在");
    }
    return image;
}
```

缺点：使用的地方需要引用头文件，一旦有改动，代价很大。

#### 2）runtime交换方法

交换方法的本质是交换两个方法的实现，即调换`xx_imageName`和`imageName`方法，达到调用`xx_imageName`其实就是调用`imageName`的作用。

那么在哪里交换比较合适？因为交换只做一次，因此放到分类`load`函数中最合适，当分类加载的时候交换方法即可。

```php
+(void)load
{
    // 获取要交换的两个方法
    // 获取类方法  用Method 接受一下
    // class ：获取哪个类方法 
    // SEL ：获取方法编号，根据SEL就能去对应的类找方法。
    Method imageNameMethod = class_getClassMethod([UIImage class], @selector(imageNamed:));
    // 获取第二个类方法
    Method xx_ccimageNameMrthod = class_getClassMethod([UIImage class], @selector(xx_ccimageNamed:));
    // 交换两个方法的实现 方法一 ，方法二。
    method_exchangeImplementations(imageNameMethod, xx_ccimageNameMrthod);
    // IMP其实就是 implementation的缩写：表示方法实现。
}
```

交换方法的内部实现：

1. 根据`SEL`在method中找到方法

2. 交换方法的实现。

![change](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rs-2.png)

⚠️**注意：交换方法时候 xx_ccimageNamed方法中就不能再调用imageNamed方法了，因为调用imageNamed方法实质上相当于调用 xx_ccimageNamed方法，会循环引用造成死循环。**

RunTime也提供了获取对象方法和方法实现的方法：

```php
// 获取方法的实现
class_getMethodImplementation(<#__unsafe_unretained Class cls#>, <#SEL name#>) 
// 获取对象方法
class_getInstanceMethod(<#__unsafe_unretained Class cls#>, <#SEL name#>)
```

## 4、动态添加方法




















































































