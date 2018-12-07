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
struct __HaviBlock__createBlock_block_impl_0 {
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
1. (void *)__HaviBlock__createBlock_block_func_0
2. &__HaviBlock__createBlock_block_desc_0_DATA
3. int _age,
4. int flags=0
其中flag是具有默认值，这里的age则是表示传入_age参数赋值给age成员；
接下来介绍






















