## OC代码转化为C++:
- clang -rewrite-objc main.m -o main.cpp // 这种方式没有指定架构例如arm64架构 其中cpp代表（c plus plus）生成 main.cpp
- 如果你直接使用会报错;请使用：xcrun -sdk iphonesimulator clang -rewrite-objc main.m
  - 将此命令设置为zsh常用命令：[详情](https://www.jianshu.com/p/bd6a94d8e49b)

## OC NSObject对象内部是如何布局的
- OC对象编译成C++代码
  - NSObject底层实现：是一个结构体，而Class就是一个指针
   ```php
  struct NSObject_IMPL {
     Class isa;
  };
  
  typedef struct objc_class *Class;
  ```
  - 那么NSObject_IMPL这个结构体占多大的内存空间呢，我们发现这个结构体只有一个成员，isa指针，而指针在64位架构中占8个字节。也就是说一个NSObjec对象所占用的内存是8个字节。
    > NSObject还有很多的类方法，这些也占用内存空间，但是这些方法占用的内存空间不在NSObject中 <br>
    > int 指针 连续操作4个字节空间 <br>
      double 指针 连续操作8个字节空间 <br>
      float 指针 连续操作4个字节空间 <br>
      char 指针 连续操作1个字节空间 <br>
  
## OC自定义对象IMP实现及内存大小
  ```php
  @interface Student : NSObject
  {
    @public
    int _no;
    int _age;
    NSString *address;
  }
  @property (nonatomic, strong) NSString *name;
  @end
  ```
  编译后：
  ```php
  struct Student_IMPL {
    struct NSObject_IMPL NSObject_IVARS;
    int _no;
    int _age;
    NSString *address;
    NSString * _Nonnull _name;
  };
  ```
- Student自定义对象占用的内存空间是ISA(8) + _no(4) + _age(4) + address（8） + _name（8） = 32

#### 总结：一个NSObjec对象所占用的内存是8个字节

***

## 窥探内存结构
##### 方式一：通过打断点。
- Debug Workflow -> viewMemory address中输入stu的地址
![debug-one](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/memroy1.png)
##### 方式二：通过lldb指令xcode自带的调试器
  ```php
    memory read 0x10074c450
    // 简写  x 0x10074c450

    // 增加读取条件
    // memory read/数量格式字节数  内存地址
    // 简写 x/数量格式字节数  内存地址
    // 格式 x是16进制，f是浮点，d是10进制
    // 字节大小   b：byte 1字节，h：half word 2字节，w：word 4字节，g：giant word 8字节

    示例：x/4xw    //   /后面表示如何读取数据 w表示4个字节4个字节读取，x表示以16进制的方式读取数据，4则表示读取4次
  ```
![debug-one](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/1434508-0f4104937adf7401.png)

> 我们可以总结内存对齐为两个原则：<br>
原则 1. 前面的地址必须是后面的地址正数倍,不是就补齐。<br>
原则 2. 整个Struct的地址必须是最大字节的整数倍。<br>

## OC对象的分类
> OC的类信息存放在哪里? <br>
对象的isa指针指向哪里?
示例代码：
```php
    #import <Foundation/Foundation.h>
    #import <objc/runtime.h>

    /* Person */ 
    @interface Person : NSObject <NSCopying>
    {
        @public
        int _age;
    }
    @property (nonatomic, assign) int height;
    - (void)personMethod;
    + (void)personClassMethod;
    @end

    @implementation Person
    - (void)personMethod {}
    + (void)personClassMethod {}
    @end

    /* Student */
    @interface Student : Person <NSCoding>
    {
        @public
        int _no;
    }
    @property (nonatomic, assign) int score;
    - (void)studentMethod;
    + (void)studentClassMethod;
    @end

    @implementation Student
    - (void)studentMethod {}
    + (void)studentClassMethod {}
    @end

    int main(int argc, const char * argv[]) {
        @autoreleasepool {      
            NSObject *object1 = [[NSObject alloc] init];
            NSObject *object2 = [[NSObject alloc] init];

            Student *stu = [[Student alloc] init];
            [Student load];

            Person *p1 = [[Person alloc] init];
            p1->_age = 10;
            [p1 personMethod];
            [Person personClassMethod];
            Person *p2 = [[Person alloc] init];
            p2->_age = 20;
        }
        return 0;
    }
  ```
    
 #### OC的对象类型：
  - instance 对象（实力对象），如：Person *person
  - class对象（类对象），
  - meta-class对象（元类对象）；
  
  ```php
    PersonOne *person = [[PersonOne alloc] init];//person 是一个instance变量
    //可以使用class方法或者runtime获取
    Class class = [person class]; //class是类对象
    Class class1 = object_getClass(person);//通过runtime获取类对象
    //class或者runtime中传入的参数如果是类对象的话，就会获取元类对象
    Class meta_class = [NSObject class];//获取元类对象
    Class meta_class1 = object_getClass([PersonOne class]);//元类
    if (class_isMetaClass(meta_class1)) {
      NSLog(@"is meta-class");
    }
  ```


