## block对对象变量的捕获：

block在使用过程中一般都是对对象的捕获，那么对对象的捕获是不是和基础类型一样？当block访问的是对象类型的话，对象在什么时候销毁？

### 查看block捕获对象类型的C++源码
```php
typedef void (^Block)(void);
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Block block;
        {
            Person *person = [[Person alloc] init];
            person.age = 10;
            
            block = ^{
                NSLog(@"------block内部%d",person.age);
            };
        } // 执行完毕，person没有被释放
        NSLog(@"--------");
    } // person 释放
    return 0; 
}

```
可以看到大括号执行之后，Person并不会被释放。之前知道Person为auto变量的时候，传入的block的变量也是person（类比self），即block会有一个强引用引用block，若果block不销毁，person也不会销毁。

```php
struct __BlockSelfObject__test_block_impl_0 {
  struct __block_impl impl;
  struct __BlockSelfObject__test_block_desc_0* Desc;
  Person *person; //这里person其实是传
  __BlockSelfObject__test_block_impl_0(void *fp, struct __BlockSelfObject__test_block_desc_0 *desc, BlockSelfObject *_self, int flags=0) : self(_self) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

但是在MRC环境下，即使block还在，但是person却被释放了。因为MRC下block是栈空间，栈空间不会对person进行强引用。

```php
//MRC环境下代码
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Block block;
        {
            Person *person = [[Person alloc] init];
            person.age = 10;
            block = ^{
                NSLog(@"------block内部%d",person.age);
            };
            [person release];
        } // person被释放
        NSLog(@"--------");
    }
    return 0;
}

```
但是对对block进行copy之后，person就不会被释放了；
```php
block = [^{
   NSLog(@"------block内部%d",person.age);
} copy];
```
‼️这是因为只要对栈空间的block进行一次copy就可以将block拷贝到堆中，person就不会被释放，这说明堆空间的block可能对person进行了一次retain操作，保障person不被销毁。堆空间的block自己销毁的时候会对持有的对象进行release操作。<br>
‼️也就是说栈空间上的block不会对对象强引用，堆空间的block有能力持有外部调用的对象，即对对象进行强引用操作。

### 有可能造成的问题：循环引用
#### 1.__weak：可以使得在作用域执行完结束后就销毁。
```php
typedef void (^Block)(void);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Block block;
        {
            Person *person = [[Person alloc] init];
            person.age = 10;
            
            __weak Person *waekPerson = person;
            block = ^{
                NSLog(@"------block内部%d",waekPerson.age);
            };
        }
        NSLog(@"--------");
    }
    return 0;
}

```
下面来看编译成C++之后weak带来的变化：<br>
> __weak 修饰变量，需要告知编译器使用ARC环境及版本会报错，添加 [-fobjc-arc -fobjc-runtime=ios-8.0.0]()

```php
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc -fobjc-arc -fobjc-runtime=ios-8.0.0 main.m
```
```php
struct __BlockSelfObject__test_block_impl_0 {
  struct __block_impl impl;
  struct __BlockSelfObject__test_block_desc_0* Desc;
  Person *__weak weakPerson; //这里添加了weak
  __BlockSelfObject__test_block_impl_0(void *fp, struct __BlockSelfObject__test_block_desc_0 *desc, BlockSelfObject *_self, int flags=0) : self(_self) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```

__weak修饰的变量，在生成的[__BlockSelfObject__test_block_impl_0]()中也会使用[__weak]()

#### __BlockSelfObject__test_block_copy_0 和 __BlockSelfObject__test_block_dispose_0

当block中捕获对象类型的时候，block结构体__BlockSelfObject__test_block_impl_0的描述结构体 __BlockSelfObject__test_block_desc_0多了两个参数 [copy]() 和[dispose]().

```php
static void __BlockSelfObject__test_block_copy_0(struct __BlockSelfObject__test_block_impl_0*dst, struct __BlockSelfObject__test_block_impl_0*src) {_Block_object_assign((void*)&dst->self, (void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static void __BlockSelfObject__test_block_dispose_0(struct __BlockSelfObject__test_block_impl_0*src) {_Block_object_dispose((void*)src->self, 3/*BLOCK_FIELD_IS_OBJECT*/);}

static struct __BlockSelfObject__test_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __BlockSelfObject__test_block_impl_0*, struct __BlockSelfObject__test_block_impl_0*);
  void (*dispose)(struct __BlockSelfObject__test_block_impl_0*);
} __BlockSelfObject__test_block_desc_0_DATA = { 0, sizeof(struct __BlockSelfObject__test_block_impl_0), __BlockSelfObject__test_block_copy_0, __BlockSelfObject__test_block_dispose_0};

```
[copy]()和[dispose]()函数传入的都是__BlockSelfObject__test_block_impl_0本身。

> copy本质就是 __main_block_copy_0 函数，__main_block_copy_0 函数内部调用 __Block_object_assign 函数，__Block_object_assign 中传入的是person对象的地址，person对象，以及8。<br>
> dispose本质就是__main_block_dispose_0函数，__main_block_dispose_0函数内部调用_Block_object_dispose函数，_Block_object_dispose函数传入的参数是person对象，以及8。

#### __Block_object_assign 函数的调用时机及作用

当block进行copy操作的时候会自动调用 __BlockSelfObject__test_block_desc_0内部的__main_block_copy_0，__main_block_copy_0函数内部会调用
__Block_object_assign函数。<br>

‼️__Block_object_assign函数会自动根据__main_block_impl_0结构体内部的person是什么类型的指针，对person对象产生强引用或者弱引用。可以理解为_Block_object_assign函数内部会对person进行引用计数器的操作，如果__main_block_impl_0结构体内person指针是__strong类型，则为强引用，引用计数+1，如果__main_block_impl_0结构体内person指针是__weak类型，则为弱引用，引用计数不变。

#### __Block_object_dispose 函数调用时机及作用
‼️当block从堆中移除时就会自动调用__main_block_desc_0中的__main_block_dispose_0函数，__main_block_dispose_0函数内部会调用_Block_object_dispose函数。
__Block_object_dispose会对person对象做释放操作，类似于release，也就是断开对person对象的引用，而person究竟是否被释放还是取决于person对象自己的引用计数。

## 总结
1. 一旦block捕获的变量是对象类型，block结构体中的<strong>__main_block_desc_0</strong>会多出两个参数[copy]()和[dispose]().因为访问的是个对象，block希望拥有这个对象，就需要对对象进行引用，也就是进行内存管理。比如说对对象进行retain操作，因此一旦block捕获的变量是对象类型就会自动生成copy和dispose来对内部引用的对象进行内存管理。<br>
2. 当block内部访问了对象类型的auto变量的时候，如果block在栈上，block内部不会对person产生强引用。不论block内部的变量是__strong还是__weak修饰，都不会对变量产生引用。<br>
3. 如果block被拷贝到堆上。copy函数会调用__Block_object_assign函数，根据auto变量的修饰符(__strong,__weak,unsafe_unretained)做出相应的操作，行程强引用或者弱引用。<br>
4. 如果block从堆中移除，dispose函数会调用__Block_object_dispose函数，自动释放引用的auto变量。

****

## 问题

### 1.下面的Person在何时销毁？
```php
PersonOne *p = [PersonOne new];
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    NSLog(@"p");
});

结果是在block执行完后person销毁
```
答：上面的代码在ARC环境中，Block作为GCD API的参数时会自动进行copy操作，因此block在堆空间，并且使用强引用访问person，因此block内部copy函数对person进行强引用，当block执行完后需要被销毁，调用dispose函数释放对person的引用，person没有强指针之后被销毁。

## 2. 下面的Person在何时销毁？
```php
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    Person *person = [[Person alloc] init];
    
    __weak Person *waekP = person;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"%@",waekP);
    });
    NSLog(@"touchBegin----------End");
}

Person 先销毁再执行block，为null

```

答：block对weakP为__weak弱引用，因此block内部copy函数对person同样进行的也是弱引用，当大括号执行结束时，person对象没有强指针引用被释放掉。因此block执行的时候打印为null

## 3. 再看下面的例子：
```php
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    Person *person = [[Person alloc] init];
    
    __weak Person *waekP = person;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSLog(@"weakP ----- %@",waekP);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"person ----- %@",person);
        });
    });
    NSLog(@"touchBegin----------End");
}
```
> 2018-12-10 -------- touchBegin----------End<br>
2018-12-10 weakP -------<Person: 0x60800006050><br>
2018-12-10 person -------<Person: 0x60800006050><br>
2018-12-10 person 对象销毁了<br>

原因是person被强引用了，不会被立刻销毁。

## 4.再看下面的例子：
```php
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    Person *person = [[Person alloc] init];
    
    __weak Person *waekP = person;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSLog(@"person ----- %@",person);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"weakP ----- %@",waekP);
        });
    });
    NSLog(@"touchBegin----------End");
}

```
> 2018-12-10 -------- touchBegin----------End<br>
2018-12-10 person -------<Person: 0x60800006050><br>
2018-12-10 person 对象销毁了<br>
2018-12-10 weakP ------null
因为在第一个gcd结束后person就释放了。

****

## block修改变量的值
示例代码
```php
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int age = 10;
        Block block = ^ {
            // age = 20; // 无法修改
            NSLog(@"%d",age);
        };
        block();
    }
    return 0;
}

```
默认情况下，block内部是不可以修改局部变量的。通过前面的分析我们知道基础类型是拷贝到block内部一份的。<br>
> [age]()是在main函数内声明的，所以age是存在于函数main的栈空间的，但是block内部的代码在__main_block_func_o函数内部。__main_block_func_0函数内部是无法访问age变量的内存空间的，两个函数的栈空间不一样，__main_block_func_0拿到的age是block结构体内部的age（age被copy过来的），因此无法在__main_block_func_0函数内部修改main函数内的变量。<br>
## 解决办法：

### 1.age变量使用static修饰
前面有提到<strong>static</strong>修饰的age变量传入block内部的时候是变量的指针，在__main_block_func_0内部可以拿到age变量的内存地址，因此可以直接修改。

### 2.使用__block修饰基础类型

__block用于解决block内部不能修改该auto的问题，__block不能修饰静态变量（static)和全局变量

```php
__block int age = 10
```
编译器会将__block修饰的变量包装成为一个对象，我们查看底层C++代码：
![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block.png)

首先被__block修饰的age变量声明变成了<strong>__Block_byref_age_0 </strong>的结构体，也就是说加上__block修饰的话捕获到block内部的变量是<strong>__Block_byref_age_0 </strong>类型的结构体。编译器在传给block之前把变量age封装成了一个__Block_byref_age_0类型的结构体。

```php
//被封装为的结构体
struct __Verify__block___createBlock_block_impl_0 {
  struct __block_impl impl;
  struct __Verify__block___createBlock_block_desc_0* Desc;
  __Block_byref_a_0 *a; // by ref
  __Verify__block___createBlock_block_impl_0(void *fp, struct __Verify__block___createBlock_block_desc_0 *desc,                         
  __Block_byref_a_0 *_a, int flags=0) : a(_a->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};

struct __Block_byref_a_0 {
    void *__isa;
    __Block_byref_a_0 *__forwarding;
    int __flags;
    int __size;
    int a;
};

static void _I_Verify__block__createBlock(Verify__block_ * self, SEL _cmd) {
     __attribute__((__blocks__(byref))) __Block_byref_a_0 a = {
                                                                (void*)0,
                                                                (__Block_byref_a_0 *)&a, 
                                                                0, 
                                                                sizeof(__Block_byref_a_0), 
                                                                10
                                                              };//先对变量age进行封装

    void (*block)(void) = ((void (*)())&__Verify__block___createBlock_block_impl_0(
                                            (void *)__Verify__block___createBlock_block_func_0,
                                            &__Verify__block___createBlock_block_desc_0_DATA, 
                                            (__Block_byref_a_0 *)&a,
                                            570425344)
                                            );
    
    ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);

}
```

![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block1.png)

>1. [__isa指针：]():__Block_byref_a_0里面也有一个isa指针，因此说明__Block_byref_a_0本质也是一个对象。<br>
2.[__forwarding]():__forwarding是__Block_byref_a_0类型的结构体，并且__forwarding存储的是(__Block_byref_a_0 *)&a，即结构体自己的地址。<br>
3.[__flag]():0<br>
4.[__size]():sizeof(__Block_byref_age_0)即__Block_byref_age_0占用的内存空间<br>
5.[age]():这个才是真正存储age的地方

接着降__Block_byref_a_0结构体age存入_block_impl_0中，并赋值给__Block_byref_a_0 *age；

![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block3.png)

在之后调用block,首先取出_block_impl_0中的age（这是个结构体），然后通过age结构体拿到__forwarding指针，上面知道__forwarding存储的就是__Block_byref_a_0结构体本身，再通过__forwarding获取结构体中的age值。<br>
在后面的NSLog函数中也是这样获取的。

![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block4.png)

#### 为什么要通过__forwarding获取age变量的值？

> ‼️__forwarding是指向自己的指针。这样做是为了方便内存管理。<br>
总结：__block为什么能够改变变量的值很清楚了。__block将变量包装成为对象，然后把age封装在结构体里面，block内部存储的变量是结构体指针，当block内部需要age变量的时候可以通过指针找到内存地址进而进行修改变量的值。

### 3.使用__block修饰对象类型

如果变量本身就是对象呢？查看c++代码：
```php
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __block Person *person = [[Person alloc] init];
        NSLog(@"%@",person);
        Block block = ^{
            person = [[Person alloc] init];
            NSLog(@"%@",person);
        };
        block();
    }
    return 0;
}

```
‼️通过查看C++代码，同样是将对象包装在了一个新的结构体中。结构体会多出来一个person对象，不一样的地方是结构体内部添加了两个内存管理函数：
[__Block_byref_id_object_copy]（)和[__Block_byref_id_object_dispose]

![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block2.png)

[__Block_byref_id_object_copy]（)和[__Block_byref_id_object_dispose]函数的调用时机及作用和之前的一致。

*****

## 1.下面的代码是否有问题？
```php
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableArray *array = [NSMutableArray array];
        Block block = ^{
            [array addObject: @"5"];
            [array addObject: @"5"];
            NSLog(@"%@",array);
        };
        block();
    }
    return 0;
}

```

答：上面的代码没有问题！因为block块中仅仅是<strong>使用了array的内存地址，往内存地址中添加内容，并没有修改array的内存地址，因此array可以不需要使用__block修饰</strong><br>
⚠️所以仅仅是使用局部变量的内存地址，而不是修改的时候，尽量不要添加__block，从源码看出，一旦添加了__block，编译器会创建响应的结构体，浪费内存。

## 2.上面提到__block修饰的age变量在编译的时候会封装为结构体，那么当外部使用age的时候，使用的是__Block_byref_age_0结构体？还是使用__Block_byref_age_0结构体中的age变量？
自定义结构体验证结构体内部结构
```php
typedef void (^Block)(void);

struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};

struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(void);
    void (*dispose)(void);
};

struct __Block_byref_age_0 {
    void *__isa;
    struct __Block_byref_age_0 *__forwarding;
    int __flags;
    int __size;
    int age;
};
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    struct __Block_byref_age_0 *age; // by ref
};

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        __block int age = 10;
        Block block = ^{
            age = 20;
            NSLog(@"age is %d",age);
        };
        block();
        struct __main_block_impl_0 *blockImpl = (__bridge struct __main_block_impl_0 *)block;
        NSLog(@"%p",&age);
    }
    return 0;
}

```
![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block6.png)

通过查看blockimpl结构体其中的内容，找到age结构体，查看两个元素：

1.__forwarding其中存储的地址确实是age结构体变量自己的地址

2.age中存储着改变后的变量20

在block中使用或者修改age的时候都是通过结构体__Block_byref_age_0找到__forwarding再找到age的。另外apple隐藏了__Block_byref_age_0的结构体实现，打印age变量的地址就是__Block_byref_age_0结构体age变量的地址。

![__block](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/__block5.png)

### ‼️通过上图的计算发现age的地址和__Block_byref_age_0结构体内部age值的地址相同。也就是说在外面使用age，代表就是结构体内的age值，也就是直接使用结构体内的 int age.

****

## __block的内存管理


























