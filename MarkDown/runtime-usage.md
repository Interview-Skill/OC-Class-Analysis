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

**如果一个类的方法非常多，其中有些方法暂时用不到。而加载类方法到内存中需要给每个方法生成映射表，但是又比较耗费资源，此时可以使用runtime动态添加方法**

动态给某个类添加方法，相当于懒加载机制，类中有许多用不到的类，可以先不加载，等用到的时候再加载。

动态添加方法：

首先我们不实现对象方法，当调用`performSelector`的时候再动态的加载方法。

```php
Person *p = [[Person alloc]init];
// 当调用 P中没有实现的方法时，动态加载方法
[p performSelector:@selector(eat)];
```

这个时候编译是不会报错的，程序运行时才会报错，因为person并没有实现`eat`方法。

而当找不到对应的方法时就会来到拦截调用，在找不到调用的方法程序崩溃之前调用的方法。  
当调用了没有实现的对象方法的时，就会调用**`+(BOOL)resolveInstanceMethod:(SEL)sel`**方法。  
当调用了没有实现的类方法的时候，就会调用**`+(BOOL)resolveClassMethod:(SEL)sel`**方法。

首先我们来到API中看一下苹果的说明，搜索 Dynamic Method Resolution 来到动态方法解析。

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rs-3.png)

**Dynamic Method Resolution的API中已经讲解的很清晰，我们可以实现方法`resolveInstanceMethod:`或者`resolveClassMethod:`方法，动态的给实例方法或者类方法添加方法和方法实现。**

所以通过这两个方法就可以知道哪些方法没有实现，从而动态添加方法。参数sel即表示没有实现的方法。

**一个objective - C方法最终都是一个C函数，默认任何一个方法都有两个参数。**  
self : 方法调用者 _cmd : 调用方法编号。我们可以使用函数class_addMethod为类添加一个方法以及实现。**

这里仿照API给的例子，动态的为P实例添加eat对象

```php
+(BOOL)resolveInstanceMethod:(SEL)sel
{
    // 动态添加eat方法
    // 首先判断sel是不是eat方法 也可以转化成字符串进行比较。    
    if (sel == @selector(eat)) {
    /** 
     第一个参数： cls:给哪个类添加方法
     第二个参数： SEL name:添加方法的编号
     第三个参数： IMP imp: 方法的实现，函数入口，函数名可与方法名不同（建议与方法名相同）
     第四个参数： types :方法类型，需要用特定符号，参考API
     */
      class_addMethod(self, sel, (IMP)eat , "v@:");
        // 处理完返回YES
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}
```

**动态添加有参数的方法**  
如果是有参数的方法，需要对方法的实现和class_addMethod方法内方法类型参数做一些修改。  
方法实现：因为在C语言函数中，所以对象参数类型只能用id代替。  
方法类型参数：因为添加了一个id参数，所以方法类型应该为**`"v@:@"`**  
来看一下代码:

```php
+(BOOL)resolveInstanceMethod:(SEL)sel
{
    if (sel == @selector(eat:)) {
        class_addMethod(self, sel, (IMP)aaaa , "v@:@");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}
void aaaa(id self ,SEL _cmd,id Num)
{
    // 实现内容
    NSLog(@"%@的%@方法动态实现了,参数为%@",self,NSStringFromSelector(_cmd),Num);
}
```

## 5.Runtime动态添加属性

首先看下对象和属性的关系：

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/rs-4.png)

对象一开始初始化的时候其属性`name`为nil，给属性赋值就是让`name`属性指向一块存储字符串的内存，使得这个对象的属性和这块内存产生关联。

那么如果想动态添加属性，其实就是动态的产生某种关联，而想要给系统动态的添加属性，只能通过分类：

#### 1.通过使用静态全局变量给分类添加属性

```php
static NSString *_name;
-(void)setName:(NSString *)name
{
    _name = name;
}
-(NSString *)name
{
    return _name;
}
```

但是这样的话`name`只要程序运行，就会一直存在内存中。

#### 2.使用Runtime

```php
-(void)setName:(NSString *)name
{
    objc_setAssociatedObject(self, @"name",name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSString *)name
{
    return objc_getAssociatedObject(self, @"name");    
}
```

1. 动态添加属性

```php
objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy);
```

参数一：**`id object`**: 给哪个对象添加属性，这里要给自己添加属性，用self。  
参数二：**`void * == id key`**: 属性名，根据key获取关联对象的属性的值，在**`objc_getAssociatedObject`**中通过次key获得属性的值并返回。  
参数三：**`id value`**: 关联的值，也就是set方法传入的值给属性去保存。  
参数四：**`objc_AssociationPolicy policy`**: 策略，属性以什么形式保存。  
有以下几种:

```php
typedef OBJC_ENUM(uintptr_t, objc_AssociationPolicy) {
    OBJC_ASSOCIATION_ASSIGN = 0,  // 指定一个弱引用相关联的对象
    OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1, // 指定相关对象的强引用，非原子性
    OBJC_ASSOCIATION_COPY_NONATOMIC = 3,  // 指定相关的对象被复制，非原子性
    OBJC_ASSOCIATION_RETAIN = 01401,  // 指定相关对象的强引用，原子性
    OBJC_ASSOCIATION_COPY = 01403     // 指定相关的对象被复制，原子性   
};
```

2. 获得属性

```php
objc_getAssociatedObject(id object, const void *key);
```

参数一：**`id object`**: 获取哪个对象里面的关联的属性。  
参数二：**`void * == id key`**: 什么属性，与**`objc_setAssociatedObject`**中的key相对应，即通过key值取出value。

此时已经成功给NSObject添加name属性，并且NSObject对象可以通过点语法为属性赋值。

```php
NSObject *objc = [[NSObject alloc]init];
objc.name = @"xx_cc";
NSLog(@"%@",objc.name);
```

## 6.RunTime字典转模型

通过给`NSObject`添加分类，声明并实现使用`Runtime`字典转模型的类方法：

```php
+ (instancetype)modelWithDict:(NSDictionary *)dict
```

首先看看使用KVC进行转化和runtime有什么区别

> **KVC** :kvc字典转模型实现原理就是遍历字典中的所有的key，然后去模型中找到对应的属性名，要求属性名和key必须一一对应，字典中所有的key必须在模型中存在。
> 
> **Runtime**: Runtime字典转模型就是遍历模型中所有的属性名，然后去字典中找到对应的key，也就是以模型为准，模型中有的，就去字典中查找。



Runtime转字典的好处就是：当服务器返回很多数据的时候，而我们只需要其中一部分，没有用的属性就没有必要进行转化。

### Runtime字典转模型过程

属性定义在类里面，那么类就有一个属性列表，属性列表以数组的形式存在，根据属性列表就可以获得类里面的所有属性，所以遍历属性列表，也可以遍历模型中所有的属性名：

1.创建模型对象：

```php
id objc = [[self alloc] init];
```

2.使用`class_copyIvarList`拷贝成员变量列表

```php
unsigned int count = 0;
Ivar *ivarList = class_copyIvarList(self, &count);
```

参数一：**`__unsafe_unretained Class cls`**: 获取哪个类的成员属性列表。这里是self，因为谁调用分类中类方法，谁就是self。  
参数二：**`unsigned int *outCount`**: 无符号int型指针，这里创建unsigned int型count，&count就是他的地址，保证在方法中可以拿到count的地址为count赋值。传出来的值为成员属性总数。  
返回值：**`Ivar *`**: 返回的是一个Ivar类型的指针 。指针默认指向的是数组的第0个元素，指针+1会向高地址移动一个Ivar单位的字节，也就是指向第一个元素。Ivar表示成员属性。

3.遍历成员变量，获取属性列表：

```php
for (int i = 0 ; i < count; i++) {
        // 获取成员属性
        Ivar ivar = ivarList[i];
}
```

4.使用`ivar_getName(ivar)`获取属性名，因为成员变量属性名返回的是C语言字符串

```php
NSString *propertyName = [NSString stringWithUTF8String:ivar_getName(ivar)]
```

5.因为获得的成员属性名，是带有_的成员属性，所以需要将下划线去掉，

```php
// 获取key
NSString *key = [propertyName substringFromIndex:1];
```

6.获取字典中key对于的value

```php
// 获取字典的value
id value = dict[key];
```

7.给模型赋值，并返回模型

```php
if (value) {
 // KVC赋值:不能传空
[objc setValue:value forKey:key];
}
return objc;
```

## 7.runtime转换模型二级转换

在






















































