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
  ```c
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
#### instance对象不唯一性；class对象和meta-class唯一性
  1. instance对象就是通过类alloc出来的对象，每次调用alloc都会产生新的instance对象；
  ```php
    NSObjcet *object1 = [[NSObjcet alloc] init];
    NSObjcet *object2 = [[NSObjcet alloc] init];
    0x600001d210a0 0x600001d21010
  ```
  > 不同的instance对象内存地址是不同的
  2. 每一个类在内存中有且只有一个class对象。
  ```php
    Class objectClass1 = [object1 class];
    Class objectClass2 = [object2 class];
    Class objectClass3 = [NSObject class];
    // runtime
    Class objectClass4 = object_getClass(object1);
    Class objectClass5 = object_getClass(object2);
    NSLog(@"%p %p %p %p %p", objectClass1, objectClass2, objectClass3, objectClass4, objectClass5);
    0x10f990f38 0x10f990f38 0x10f990f38 0x10f990f38 0x10f990f38
  ```
  3. 每个类在内存中有且只有一个meta-class对象。
  ```php
    Class metaObjectClass1 = object_getClass([NSObject class]);
    Class metaObjectClass2 = [NSObject class];
    NSLog(@"%p %p", metaObjectClass1, metaObjectClass2);
    0x10e050ee8 0x10e050f38
  ```
 
#### instance/class/meta-class对象存放的信息
  1. instance对象在内存中存储的信息包括
    - isa指针
    - 其成员变量
  ![instance-message](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/instance.png)
  
  2. class对象在内存中存放的信息包括：
    - isa指针
    - superclass指针
    - 类的属性信息（@property），类的成员变量信息（ivar）
    - 类的对象方法信息（instance method），类的协议信息（protocol）
    > 我们在runtime的源码中搜索objc_class，然后在obj-runtime-new.h这找到了class的结构<br>
    class_ro_t:代表只读；class_rw_t:readWrite
  ![class-message](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/class.png)
 ```php
  struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // 方法缓存
    class_data_bits_t bits;    // 用于获取类的具体信息
    class_rw_t *data() { 
        return bits.data();
    }

  };
  struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    const class_ro_t *ro;
    method_array_t methods;    //方法列表
    property_array_t properties; //属性列表
    protocol_array_t protocols;   //协议列表

  };     
  struct class_ro_t {
    const char * name;   //类名
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;    //成员变量列表

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;

    method_list_t *baseMethods() const {
        return baseMethodList;
    }

  };
 ```
 3. meta-class对象在内存中存放的信息包括：
  - isa指针
  - superclass指针
  - 类的类方法的信息（class method）
  ![meta-class](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/meta-class.png)
  > meta-class对象和class对象的内存结构是一样的，所以meta-class中也有类的属性信息，类的对象方法信息等成员变量，但是其中的值可能是空的。
 
#### 调用instance方法/class方式runtime是如何找到方法实现的？

- instance对象调用对象方法：
 ```php
 [stu studentMethod];
 ```
 > instance的isa指向class，当调用对象方法时，通过instance的isa找到class，最后找到对象方法的实现进行调用。
 
- 当类对象调用类方法的时候：
```php
 [Student studentMethod];
 ```
 > class的isa指向meta-class;当调用类方法时，通过class的isa找到meta-class，最后找到类方法的实现进行调用
 
 - 当对象调用其父类对象方法的时候:要使用到class类对象superclass指针
 ```php
[stu personMethod];
[stu init];
```
> 当Student的instance对象要调用Person的对象方法时，会先通过isa找到Student的class，然后通过superclass找到Person的class，最后找到对象方法的实现进行调用，同样如果Person发现自己没有响应的对象方法，又会通过Person的superclass指针找到NSObject的class对象，去寻找响应的方法

- 当类对象调用父类的类方法时:
```php
[Student personClassMethod];
[Student load];
```
> 当Student的class要调用Person的类方法时，会先通过isa找到Student的meta-class，然后通过superclass找到Person的meta-class，最后找到类方法的实现进行调用

### 对isa、superclass总结

> 1.instance的isa指向class <br>
> 2.class的isa指向meta-class<br>
> 3.meta-class的isa指向基类的meta-class，基类的isa指向自己<br>
> 4.class的superclass指向父类的class，如果没有父类，superclass指针为nil<br>
> 5.meta-class的superclass指向父类的meta-class，基类的meta-class的superclass指向基类的class<br>
> 6.instance调用对象方法的轨迹，isa找到class，方法不存在，就通过superclass找父类<br>
> 7.class调用类方法的轨迹，isa找meta-class，方法不存在，就通过superclass找父类<br>




#### Question:
  1. 实例对象的方法的代码放在什么地方呢？
  2. 类的方法的信息，协议的信息，属性的信息都存放在什么地方呢？
  3. 
 

