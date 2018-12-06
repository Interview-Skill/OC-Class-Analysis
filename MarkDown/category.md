# 面试题
1. Category的实现原理，以及Category为什么只能添加方法不能添加成员变量（属性）
2. Category中有load方法吗？load方法在什么时候调用？load方法可以继承吗？
3. load/initilize方法的区别，以及他们在Category被重写的时候的调用顺序？

## Category本质探索
```php
Presen类 
// Presen.h
#import <Foundation/Foundation.h>
@interface Preson : NSObject
{
    int _age;
}
- (void)run;
@end

// Presen.m
#import "Preson.h"
@implementation Preson
- (void)run
{
    NSLog(@"Person - run");
}
@end

Presen扩展1
// Presen+Test.h
#import "Preson.h"
@interface Preson (Test) <NSCopying>
- (void)test;
+ (void)abc;
@property (assign, nonatomic) int age;
- (void)setAge:(int)age;
- (int)age;
@end

// Presen+Test.m
#import "Preson+Test.h"
@implementation Preson (Test)
- (void)test
{
}

+ (void)abc
{
}
- (void)setAge:(int)age
{
}
- (int)age
{
    return 10;
}
@end

Presen分类2
// Preson+Test2.h
#import "Preson.h"
@interface Preson (Test2)
@end

// Preson+Test2.m
#import "Preson+Test2.h"
@implementation Preson (Test2)
- (void)run
{
    NSLog(@"Person (Test2) - run");
}
@end

```
> Category中的方法依然是存储在类对象方法中的，同本类对象方法存储在同一个地方，调用步骤和对象方法是一致的。下面通过查看runtime源码来验证：
### 1. Category本质在内存中是一个结构体category_t：

```ph
