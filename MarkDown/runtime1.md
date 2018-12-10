
# isa 的本质

之前学习OC对象的本质，了解到每个对象都有一个isa指针，在[__arm64__]()之前，isa仅仅是一个指针，保存着<strong>类对象或元类对象</strong>的内存地址，在[__arm64__]()之后，apple对isa做了优化，变成了一个union结构，同时使用位域来存储更多的东西。

现在OC对象的isa指针并不是直接的指向类对象或者元类对象，而是需要经过[&ISA_MASK]()通过运算才能获得类对象或者元类对象的地址。下面讨论apple为什么这样做？

## 重温源码中isa指针，看看isa指针的本质。
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

### 位域技术：
1）定义方式：
```php
位域定义与结构定义相仿，其形式为：
struct 位域结构名
{

  类型说明符  位域名：位域长度
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




