# 面试题：
1. block原理是什么？本质是什么？
2. __block作用是什么？有什么注意点？
3. block的属性修饰词为什么是copy？使用block有哪些使用注意？
4. block在修改NSMutableArray，需不需要使用__blcok?

> 首先：block本质也是一个OC对象，内部也有一个isa指针。block是封装了函数调用以及函数调用环境的OC对象。

## 探寻block的本质
```php
- (void)createBlock
{
	int age = 10;
	void(^block)(int, int) = ^(int a, int b) {
		NSLog(@"this is an block, a = %d, b = %d",a,b);
		NSLog(@"this is an block, age = %d",age );
	};
	block(3,5);
}
```
使用下面的命令将.m文件转化为C++
```php
xcrun -sdk iphonesimulator clang -rewrite-objc HaviBlock.m
```
下面是C++结构的block：

```php
struct __HaviBlock__createBlock_block_impl_0 {//block的C++结构
  struct __block_impl impl;
  struct __HaviBlock__createBlock_block_desc_0* Desc;
  int age;
  __HaviBlock__createBlock_block_impl_0(void *fp, struct __HaviBlock__createBlock_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
static void __HaviBlock__createBlock_block_func_0(struct __HaviBlock__createBlock_block_impl_0 *__cself, int a, int b) {
  int age = __cself->age; // bound by copy//从这里可以看到是对外面的变量copy过来的
  __Block_byref_age_0 *age = __cself->age; // bound by ref//如果使用了__block，是对外面的变量创建了个引用

  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviBlock_1ee770_mi_0,a,b);
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviBlock_1ee770_mi_1,age );
 }

static struct __HaviBlock__createBlock_block_desc_0 {
  size_t reserved;
  size_t Block_size;
} __HaviBlock__createBlock_block_desc_0_DATA = { 0, sizeof(struct __HaviBlock__createBlock_block_impl_0)};

static void _I_HaviBlock_createBlock(HaviBlock * self, SEL _cmd) {//这个就是block中的create函数
 int age = 10;
 void(*block)(int, int) = ((void (*)(int, int))&__HaviBlock__createBlock_block_impl_0((void *)__HaviBlock__createBlock_block_func_0, &__HaviBlock__createBlock_block_desc_0_DATA, age));
 ((void (*)(__block_impl *, int, int))((__block_impl *)block)->FuncPtr)((__block_impl *)block, 3, 5);
}

```
### 1.定义block变量
```php
void(*block)(int, int) = ((void (*)(int, int))&__HaviBlock__createBlock_block_impl_0((void *)__HaviBlock__createBlock_block_func_0, &__HaviBlock__createBlock_block_desc_0_DATA, age));
```
从上面的定义，block中调用了__HaviBlock__createBlock_block_impl_0函数，并且将__HaviBlock__createBlock_block_impl_0函数的地址赋值给了blcok.下面来看下__HaviBlock__createBlock_block_impl_0内部结构：

### 2.__HaviBlock__createBlock_block_impl_0函数内部结构体：

```php
struct __HaviBlock__createBlock_block_impl_0

{
  struct __block_impl impl;
  struct __HaviBlock__createBlock_block_desc_0* Desc;
  int age;
  __HaviBlock__createBlock_block_impl_0(void *fp, struct __HaviBlock__createBlock_block_desc_0 *desc, int _age, int flags=0) : age(_age) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```
__HaviBlock__createBlock_block_impl_0 结构体内有一个同名的构造函数__HaviBlock__createBlock_block_impl_0，构造函数中对变量进行了赋值，并最终返回了一个结构体。<br>

也就是说最终将__HaviBlock__createBlock_block_impl_0结构体的地址赋值给了block变量！<br>

__HaviBlock__createBlock_block_impl_0构造函数有四个参数：
1）. (void *)__HaviBlock__createBlock_block_func_0
2）. &__HaviBlock__createBlock_block_desc_0_DATA
3）. int _age,
4）. int flags=0
其中flag是具有默认值，这里的age则是表示传入_age参数赋值给age成员；<br>
### 接下来介绍这三个参数：

#### 1.__HaviBlock__createBlock_block_func_0
```php
static void __HaviBlock__createBlock_block_func_0(struct __HaviBlock__createBlock_block_impl_0 *__cself, int a, int b) {
  int age = __cself->age; // bound by copy

  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviBlock_1ee770_mi_0,a,b);
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviBlock_1ee770_mi_1,age );
}
```
在这个函数中，首先取出age的值，紧接着可以看到两个熟悉的NSLog，这个就是我们再block中写下的代码。所以__HaviBlock__createBlock_block_func_0函数中其实保存着我们在block中写下的代码。__HaviBlock__createBlock_block_impl_0中传入的是__HaviBlock__createBlock_block_func_0，<strong> 就是说我们再block中写下的代码被封装成为__HaviBlock__createBlock_block_func_0</strong>并把__HaviBlock__createBlock_block_func_0函数的地址保存在__HaviBlock__createBlock_block_impl_0中。

#### 2.__HaviBlock__createBlock_block_desc_0_DATA
```php

static struct __HaviBlock__createBlock_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __HaviBlock__createBlock_block_impl_0*, struct __HaviBlock__createBlock_block_impl_0*);
  void (*dispose)(struct __HaviBlock__createBlock_block_impl_0*);
} __HaviBlock__createBlock_block_desc_0_DATA = { 0, sizeof(struct __HaviBlock__createBlock_block_impl_0), __HaviBlock__createBlock_block_copy_0, __HaviBlock__createBlock_block_dispose_0};

```
__HaviBlock__createBlock_block_desc_0中存储着两个参数：reserved 和 Block_size，并且reserved赋值为0，Block_size则存储着__HaviBlock__createBlock_block_impl_0的占用空间的大小。最后将__HaviBlock__createBlock_block_desc_0地址传入__HaviBlock__createBlock_block_impl_0中的Desc.

#### 3. age
age是我们定义的局部变量。因为在block中使用age局部变量，所以在block声明的时候会将age作为参数传入，<strong>也就是说block会捕获age变量 </strong>
如果在block中没有使用age，则只会传入__HaviBlock__createBlock_block_func_0 和__HaviBlock__createBlock_block_desc_0_DATA这两个参数。
<br>
##### 在这里可以思考：为什么在我们定义block之后，再改变age的值，在block调用的时候无效？
```php
int age = 10;
void(^block)(int ,int) = ^(int a, int b){
     NSLog(@"this is block,a = %d,b = %d",a,b);
     NSLog(@"this is block,age = %d",age);
};
     age = 20;
     block(3,5); 
     // log: this is block,a = 3,b = 5
     //      this is block,age = 10

```
A:因为在block定义的时候，已经将age的值传入__HaviBlock__createBlock_block_impl_0结构体中，并在调用的时候讲age从block中取出来使用，因此在block定义之后对局部变量进行改变无法被block捕获的。

## 重新探究__HaviBlock__createBlock_block_impl_0结构体
```php
struct __HaviBlock__createBlock_block_impl_0 {
  struct __block_impl impl;
  struct __HaviBlock__createBlock_block_desc_0* Desc;
  __Block_byref_age_0 *age; // by ref
  __HaviBlock__createBlock_block_impl_0(void *fp, struct __HaviBlock__createBlock_block_desc_0 *desc, __Block_byref_age_0 *_age, int flags=0) : age(_age->__forwarding) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};
```
__HaviBlock__createBlock_block_impl_0第一个变量就是__block_impl结构体：

```php
struct __block_impl {
  void *isa;
  int Flags;
  int Reserved;
  void *FuncPtr;
};
```

从这里__HaviBlock__createBlock_block_impl_0内部有一个isa指针，因此说明block本质上是一个OC对象。而在
__HaviBlock__createBlock_block_impl_0 构造函数中传入的值存储在__HaviBlock__createBlock_block_impl_0结构体中，最后将改结构体的地址赋值给block。

### 根据__HaviBlock__createBlock_block_impl_0三个参数的分析得出结论：<br>
1. __block_impl结构体中的指针存储着&_NSConcreteStackBlock地址，可以暂时理解为类对象地址，block就是_NSConcreteStackBlock类型的。<br>
2. block代码中的代码被封装成为__HaviBlock__createBlock_block_func_0，FuncPtr则存储着__HaviBlock__createBlock_block_func_0的地址<br>
3. Desc指向__HaviBlock__createBlock_block_desc_0结构体对象，其中存储着__HaviBlock__createBlock_block_impl_0结构体占用的空间；

## 调用block执行内部函数：
```php

 ((void (*)(__block_impl *, int, int))((__block_impl *)block)->FuncPtr)((__block_impl *)block, 3, 5);

```

上面的代码可以看出block通过block找到FunPtr直接调用，通过上面的源代码我们知道block指向的是__HaviBlock__createBlock_block_impl_0类型的结构体，但是在__HaviBlock__createBlock_block_impl_0中并没有直接可以找到FunPtr，而FunPtr存储在__block_impl中，为什么block可以直接调用__block_impl中的FunPtr呢？<br>

是因为（__blcok_impl*）block将block强制转化为__block_impl类型的，因为__block_impl是__HaviBlock__createBlock_block_impl_0结构体的第一个成员，也就是说__block_impl的内存地址就是__HaviBlock__createBlock_block_impl_0结构体内存地址的开发。所以可以转化成功。（why?todo）<br>

FunPtr中存储着通过代码块封装的函数地址，那么调用这个函数，也就是执行代码快中的代码。回头看__HaviBlock__createBlock_block_func_0，可以发现第一个参数是_HaviBlock__createBlock_block_impl_0类型的指针，也就是说将block传入到了__HaviBlock__createBlock_block_func_0中，方便重中取出block捕获的值。

## 验证Block本质确实是__HaviBlock__createBlock_block_impl_0结构体
方法：我们使用自定义和Block一致的结构体，并将block内部的结构体强制转化为我们自定义的结构体：
```php
struct __main_block_desc_0 { 
    size_t reserved;
    size_t Block_size;
};
struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};
// 模仿系统__main_block_impl_0结构体
struct __main_block_impl_0 { 
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int age;
};
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int age = 10;
        void(^block)(int ,int) = ^(int a, int b){
            NSLog(@"this is block,a = %d,b = %d",a,b);
            NSLog(@"this is block,age = %d",age);
        };
// 将底层的结构体强制转化为我们自己写的结构体，通过我们自定义的结构体探寻block底层结构体
        struct __main_block_impl_0 *blockStruct = (__bridge struct __main_block_impl_0 *)block;
        block(3,5);
    }
    return 0;
}

```
通过打断点可以查看：
![duan1](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/block2.png)
下面进入block内部，看一下堆栈信息中的函数调用地址。<strong>Debug workflow -> slways show Disassembly</strong>

![duan2](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/block5.png)

## 总结：到这里我们从源码查看了所有和block有关的结构体，下面通过一张图解释各个结构体的关系：

![duan3](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/Block.png)

### Block的底层数据结构：

![duan3](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/block7.png)

*****

# Block捕获变量

为了保证block能够正常访问外部变量，block有一个变量捕获机制：

## 1. 局部变量
### 1）auto变量
上面的代码我们已经了解了block对age变量的捕获。
auto变量离开作用域就会销毁，<strong>局部变量前面默认添加auto关键字</strong>。自定变量会捕获到block内部，也就是说在block内部会新增一个变量专门来存储变量值。auto变量只存在局部变量中，访问方式是值传递，通过对age源码的查看可以确认。

### 2）static变量
static修饰的变量为指针传递，就是说他是通过传递该值的地址到block内部，看看下源码：
```php
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        auto int age = 10;
        static int ageB = 11;
        void(^block)(void) = ^{
            NSLog(@"hello, a = %d, b = %d", age,ageB);
        };
        a = 1;
        b = 2;
        block();
    }
    return 0;
}
// log : block本质[57465:18555229] hello, a = 10, b = 2
// block中a的值没有被改变而b的值随外部变化而变化。

```
我们经过xcrun编译为C++：
```php
struct __HaviNewBlock__verifyBlock_block_impl_0 {
  struct __block_impl impl;
  struct __HaviNewBlock__verifyBlock_block_desc_0* Desc;
  int age;
  int *ageB;	//这里可以看到使用static修饰的变量在编译为c++后是指针
  __HaviNewBlock__verifyBlock_block_impl_0(void *fp, struct __HaviNewBlock__verifyBlock_block_desc_0 *desc, int _age, int *_ageB, int flags=0) : age(_age), ageB(_ageB) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
  }
};

static void __HaviNewBlock__verifyBlock_block_func_0(struct __HaviNewBlock__verifyBlock_block_impl_0 *__cself, int a, int b) {
  int age = __cself->age; // bound by copy
  int *ageB = __cself->ageB; // bound by copy

  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviNewBlock_49c829_mi_2,a,b);
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviNewBlock_49c829_mi_3,age );
  NSLog((NSString *)&__NSConstantStringImpl__var_folders_82__00fdxvn217fjfl3my96zr0509801s_T_HaviNewBlock_49c829_mi_4,(*ageB));
 }
 
 从这里我们可以看出ageB穿进去的是地址
 void(*block)(int, int) = ((void (*)(int, int))&__HaviNewBlock__verifyBlock_block_impl_0((void *)__HaviNewBlock__verifyBlock_block_func_0, &__HaviNewBlock__verifyBlock_block_desc_0_DATA, age, &ageB));


```

从源代码中看出，age和ageB两个变量都被捕获到了block内部，但是age是通过值传递的，ageB是传递的是地址。
为什么有这种差异？因为自动变量随时有可能被销毁，block在执行的时候有可能自动变量被销毁了，如果这个时候再去访问被销毁的地址就会找不到这个内存地址，因此自动变量一定是值传递而不是指针传递了。而静态变量是不会被销毁的，因此可以使用指针传递。因为传递的是值地址，在block调用前修改，会体现出来。

## 全局变量
我们看下全局的变量捕获情况：
```php
int a = 10;
static int b = 11;
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void(^block)(void) = ^{
            NSLog(@"hello, a = %d, b = %d", a,b);
        };
        a = 1;
        b = 2;
        block();
    }
    return 0;
}
// log hello, a = 1, b = 2

```
我们生成c++
![c++](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/c%2B%2B.png)
通过上面的代码发现block_impl_0中并没有添加任何变量，因为block不需要捕获全局变量，因为全局变量在哪里都可以访问。<br>
<strong>因为局域变量需要跨函数访问所以需要捕获，全局变量在哪里都可以访问，所以不需要捕获</strong>
![c++](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/auto-static.png)

#### 局部

























