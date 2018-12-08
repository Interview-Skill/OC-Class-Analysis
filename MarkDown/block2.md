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

#### __Block_object_dispose函数调用时机及作用
‼️当block从堆中移除时就会自动调用__main_block_desc_0中的__main_block_dispose_0函数，__main_block_dispose_0函数内部会调用_Block_object_dispose函数。
__Block_object_dispose会对person对象做释放操作，类似于release，也就是断开对person对象的引用，而person究竟是否被释放还是取决于person对象自己的引用计数。






