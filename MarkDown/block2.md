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
但是对

