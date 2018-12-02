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

## 总结：一个NSObjec对象所占用的内存是8个字节

***

## 窥探内存结构
### 方式一：通过打断点。
- Debug Workflow -> viewMemory address中输入stu的地址
 
