
# isa 的本质

之前学习OC对象的本质，了解到每个对象都有一个isa指针，在[__arm64__]()之前，isa仅仅是一个指针，保存着<strong>类对象或元类对象</strong>的内存地址，在[__arm64__]()之后，apple对isa做了优化，变成了一个union结构，同时使用位域来存储更多的东西。

现在OC对象的isa指针并不是直接的指向类对象或者元类对象，而是需要经过[&ISA_MASK]()通过运算才能获得类对象或者元类对象的地址。下面讨论apple为什么这样做？

## 一、重温源码中isa指针，看看isa指针的本质。
```php
任何一个对象C++结构：

struct AnyObject_IMPL {
	struct NSObject_IMPL NSObject_IVARS;
	int _age;
};

struct NSObject_IMPL {
	Class isa;
};

```

可以看到每个对象都有一个isa指针：

```php
typedef struct objc_class *Class;

struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags

    class_rw_t *data() { 
        return bits.data();
    }
    void setData(class_rw_t *newData) {
        bits.setData(newData);
    }
    ....
 }
 
 
struct objc_object {
private:
    isa_t isa;
    ...
}

```

下面是重点：isa_t是一个union：
```php
union isa_t 
{
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;

#if SUPPORT_PACKED_ISA

    // extra_rc must be the MSB-most field (so it matches carry/overflow flags)
    // nonpointer must be the LSB (fixme or get rid of it)
    // shiftcls must occupy the same bits that a real class pointer would
    // bits + RC_ONE is equivalent to extra_rc + 1
    // RC_HALF is the high bit of extra_rc (i.e. half of its range)

    // future expansion:
    // uintptr_t fast_rr : 1;     // no r/r overrides
    // uintptr_t lock : 2;        // lock for atomic property, @synch
    // uintptr_t extraBytes : 1;  // allocated with extra bytes

# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
#   define ISA_MAGIC_MASK  0x000003f000000001ULL
#   define ISA_MAGIC_VALUE 0x000001a000000001ULL
    struct {
        uintptr_t nonpointer        : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 33; // MACH_VM_MAX_ADDRESS 0x1000000000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 19;
#       define RC_ONE   (1ULL<<45)
#       define RC_HALF  (1ULL<<18)
    };

# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x001f800000000001ULL
#   define ISA_MAGIC_VALUE 0x001d800000000001ULL
    struct {
        uintptr_t nonpointer        : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 44; // MACH_VM_MAX_ADDRESS 0x7fffffe00000
        uintptr_t magic             : 6;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 8;
#       define RC_ONE   (1ULL<<56)
#       define RC_HALF  (1ULL<<7)
    };

# else
#   error unknown architecture for packed isa
# endif

// SUPPORT_PACKED_ISA
#endif


#if SUPPORT_INDEXED_ISA

# if  __ARM_ARCH_7K__ >= 2

#   define ISA_INDEX_IS_NPI      1
#   define ISA_INDEX_MASK        0x0001FFFC
#   define ISA_INDEX_SHIFT       2
#   define ISA_INDEX_BITS        15
#   define ISA_INDEX_COUNT       (1 << ISA_INDEX_BITS)
#   define ISA_INDEX_MAGIC_MASK  0x001E0001
#   define ISA_INDEX_MAGIC_VALUE 0x001C0001
    struct {
        uintptr_t nonpointer        : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t indexcls          : 15;
        uintptr_t magic             : 4;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 7;
#       define RC_ONE   (1ULL<<25)
#       define RC_HALF  (1ULL<<6)
    };

# else
#   error unknown architecture for indexed isa
# endif

// SUPPORT_INDEXED_ISA
#endif

};
```

## 前景铺垫：
上述的代码中isa_t是union类型，union表示共用体。可以看到共用体内有一个结构体，结构体内定义了一些变量，变量后面的值代表了改变量占用的多少个二进制位，也就是位域技术。

### 1.位域技术：
1）定义方式：
```php
位域定义与结构定义相仿，其形式为：
struct 位域结构名
{
  类型说明符  位域名：位域长度
  位段的定义格式为:
  type  [var]: digits
  ......
};
例如：
struct bs
{
    int a:8;
    int b:2;
    int c:6;
};

```
type只能为int，unsigned int，signed int，char, unsigned char 五种类型之一，digits表示该位段所占的二进制位数；<br>
位段长度digits不能超过类型type对应的数据类型占用的大小，如若type为char，则digits不能超过8，为int则digits不能超过32
#### [位域在本质上就是一种结构类型， 不过其成员是按二进位分配的。]()
[详细请参考](https://www.jianshu.com/p/0481a7b551b8)
[isa](http://www.cocoachina.com/ios/20160503/16060.html)

### 2.共用体
在进行某些算法的C语言编程的时候，需要使用几种不同类型的变量存放到同一端内存中。也称为覆盖技术，几个变量相互覆盖。这几种变量共同占用一段内存，这称为共用体。
```php
(lldb) p/x &bf
(HGBitFiled *) $1 = 0x00007ffee8d55978
(lldb) x 0x00007ffee8d55978
0x7ffee8d55978: 22 00 00 00 00 00 00 00 80 e3 80 cc 9c 7f 00 00  "...............
0x7ffee8d55988: 40 e9 ea 06 01 00 00 00 50 0e 63 0b 01 00 00 00  @.......P.c.....
(lldb) p/x bf
(HGBitFiled) $2 = (tall = 0x0000000000000000, rich = 0x0000000000000001, handsome = 0x0000000000000004)
```


## 二、探寻Apple为什么使用共用体及其好处
1. 模仿底层的做法：

```php
@interface Person : NSObject

@property (nonatomic, assign, getter=isTall) BOOL tall;
@property (nonatomic, assign, getter=isRich) BOOL rich;
@property (nonatomic, assign, getter=isHansome) BOOL handsome;

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"%zd", class_getInstanceSize([Person class]));
    }
    return 0;
}
// 打印内容
// Runtime - [52235:3160607] 16

```
上面的代码中Person含有3个bool值，打印person类对象占据的内存空间为16字节，也就是[(isa指针 = 8)+ (Bool tall = 1) + (Bool rich = 1) + (bool handsome = 1) = 13]().由于内存对齐原则是16.

上面提到共用体中的变量可以相互覆盖，可以使不同的变量存放在一段内存中，可以节省内存空间。

而Bool值只有两种情况0或者1，但是却占据了一个字节的内存空间，而一个字节的内存空间有8个二进制位，并且二进制位只有0和1，那么是不是可以使用一个二进制位来表示BOOL值呢，也就是3个bool值只需要3个二进制位，也就是一个内存空间？这个怎么实现？

从上面看出使用属性的方法肯定不行，这样会占用3个内存空间。

### 解决思路

#### 1.如何表示：添加一个char类型的成员变量，char类型占据一个字节的内存空间，也就是8个二进制位，然后使用最后的3个二进制位存储3个bool值。

```php
@interface Person()
{
   char _tallRichHandsome;
}
```
例如<strong>_tallRichHandsome的值为 0b 0000 0010</strong>那么只是用二进制位的后三位表示，分别为其赋值0或者1来代表tall,rich,handsome的值。
![isa](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/isa1.png)

#### 2.如何取值
那么我们如何去8个二进制中的某一位或者给其中的一位进行赋值呢？

我们可以使用按位与取出响应位置的值。
<strong>&: 按位与，同真为真，其他未假</strong>
```php
// 示例
// 取出倒数第三位 tall
  0000 0010
& 0000 0100
------------
  0000 0000  // 取出倒数第三位的值为0，其他位都置为0

// 取出倒数第二位 rich
  0000 0010
& 0000 0010
------------
  0000 0010 // 取出倒数第二位的值为1，其他位都置为0

```

按位与可以取出特定的bit位，只需要将取出的bit位设置为1,其他位设定为0.

对上面的代码进行优化：
```php
#define TallMask 0b00000100
#define RichMask 0b00000010
#define HandsomeMask 0b00000001

- (BOOL)isTall
{
	return !!(_tallRichHandsome & TallMask);
}

- (BOOL)isRich
{
	return  !!(_tallRichHandsome & RichMask);
}

- (BOOL)isHandsome
{
	return !!(_tallRichHandsome & HandsomeMask);
}
```
在上面的代码中使用!!来讲二进制数转化为bool类型。

```php
// 取出倒数第二位 rich
  0000 0010  // _tallRichHandsome
& 0000 0010 // RichMask
------------
  0000 0010 // 取出rich的值为1，其他位都置为0
```
上面代码中[__tallrichHandsome & TallMask]()的值是[0b00000010]也就是2.但是我们需要一个bool值类型，那么!!2会将2先转化为0然后转化为1.相反按位与之后值0同样需要!!0转化。

‼️<strong>上面代码中定义了三个宏，用来分别进行按位与运算而取出响应的值，一般用来和按位与&运算的值成为掩码。</strong>

为了能更清晰的表示掩码是为了取出哪一位，上面的三个宏可以使用[<<](左移)来优化。

![isa](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/isa2.png)

优化后：
```php
#define TallMask 1<<2 //0b0000 0100 = 4
#define RichMask 1<<1 //0b0000 0010 = 2
#define HandsomeMask 1<<0 //0
```

#### 3.如何设值？
<strong>我们可以使用[|(按位或)]() | :按位或，只要有一个为1就是1，否则为0</strong>













