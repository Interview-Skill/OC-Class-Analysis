# Class的结构重认识

首先来看下Class内部的结构代码：

```php
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
    ...
}

class_rw_t* data() {
        return (class_rw_t *)(bits & FAST_DATA_MASK);
}

```

## class_rw_t

从这个return (class_rw_t *)(bits & FAST_DATA_MASK);可以知道<strong>bits & FAST_DATA_MASK</strong>位运算之后可以得到 class_rw_t,而在 class_rw_t 中存储着方法列表、属性列表、以及协议列表，来看下class_rw_t中的代码：

```php
struct class_rw_t {
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags;
    uint32_t version;

    const class_ro_t *ro;

    method_array_t methods;
    property_array_t properties;
    protocol_array_t protocols;

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;

#if SUPPORT_INDEXED_ISA
    uint32_t index;
#endif

    void setFlags(uint32_t set) 
    {
        OSAtomicOr32Barrier(set, &flags);
    }

    void clearFlags(uint32_t clear) 
    {
        OSAtomicXor32Barrier(clear, &flags);
    }

    // set and clear must not overlap
    void changeFlags(uint32_t set, uint32_t clear) 
    {
        assert((set & clear) == 0);

        uint32_t oldf, newf;
        do {
            oldf = flags;
            newf = (oldf | set) & ~clear;
        } while (!OSAtomicCompareAndSwap32Barrier(oldf, newf, (volatile int32_t *)&flags));
    }
};

```
上面的代码中，[method_array_t、property_array_t、protocol_array_t]()其实都是二维数组，进到method_array_t, property_array_t, protocol_array_t 内部看一下。这里以 method_array_t为例，method_array_t 本身就是一个数组，数组里面存放的是数组method_list_t, method_list_t里面存放的是method_t.

```php
/***********************************************************************
* list_array_tt<Element, List>
* Generic implementation for metadata that can be augmented by categories.
*
* Element is the underlying metadata type (e.g. method_t)
* List is the metadata's list type (e.g. method_list_t)
*
* A list_array_tt has one of three values:
* - empty
* - a pointer to a single list
* - an array of pointers to lists
*
* countLists/beginLists/endLists iterate the metadata lists
* count/begin/end iterate the underlying metadata elements
**********************************************************************/
class method_array_t : 
    public list_array_tt<method_t, method_list_t> 
{
    typedef list_array_tt<method_t, method_list_t> Super;

 public:
    method_list_t **beginCategoryMethodLists() {
        return beginLists();
    }
    
    method_list_t **endCategoryMethodLists(Class cls);

    method_array_t duplicate() {
        return Super::duplicate<method_array_t>();
    }
};


class property_array_t : 
    public list_array_tt<property_t, property_list_t> 
{
    typedef list_array_tt<property_t, property_list_t> Super;

 public:
    property_array_t duplicate() {
        return Super::duplicate<property_array_t>();
    }
};


class protocol_array_t : 
    public list_array_tt<protocol_ref_t, protocol_list_t> 
{
    typedef list_array_tt<protocol_ref_t, protocol_list_t> Super;

 public:
    protocol_array_t duplicate() {
        return Super::duplicate<protocol_array_t>();
    }
};
```
class_rw_t里面的methods/properties/protocols是二维数组，是可读可写的，其中包含了类的初始化内容以及分类的内容。

![array](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/method-array-t.png)

## class_ro_t

之前的源码探究中，知道 class_ro_t中也有存储方法、属性、协议列表，除此之外还有成员变量。

```php
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;
    
    const char * name;
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;

    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};
```

从源码中看出，class_ro_t *ro是只读的，内部直接存储的就是 method_list_t,protocol_list_t,property_list_t 类型的一维数组，数组里面分别存放的是类的初始信息，以 method_list_t 为例，里面存放的就是method_t,但是是只读的.

### ‼️总结
class_tw_t中methods是一个二维数组的结构，并且可读可写，因此可以动态的添加方法，因此更加便利分类方法的添加。在category原理中我们知道，attachList 函数通过 memmove 和 memcpy 两个操作将分类的方法列表合并到本类的方法列表中。在此时就将分类的方法和本类的方法整合到一起。

其实从一开始类的方法，属性，成员变量和协议列表都是存放在class_ro_t中的，当程序运行的时候，需要将分类中的列表跟类的初始化的列表合并在一起，就会将class_rw_t中的列表和分类中的列表合并之后存放到class_rw_t中，也就是说class_rw_t中的部分列表是从class_ro_t中取出来的。并且最终和分类进行合并。

## realizeClass部分源码

```php
/***********************************************************************
* realizeClass
* Performs first-time initialization on class cls, 
* including allocating its read-write data.
* Returns the real class structure for the class. 
* Locking: runtimeLock must be write-locked by the caller
**********************************************************************/
static Class realizeClass(Class cls)
{
    runtimeLock.assertWriting();

    const class_ro_t *ro;
    class_rw_t *rw;
    Class supercls;
    Class metacls;
    bool isMeta;

    if (!cls) return nil;
    if (cls->isRealized()) return cls;
    assert(cls == remapClass(cls));

    // fixme verify class is not in an un-dlopened part of the shared cache?

    ro = (const class_ro_t *)cls->data();
    if (ro->flags & RO_FUTURE) {
        // This was a future class. rw data is already allocated.
        rw = cls->data();
        ro = cls->data()->ro;
        cls->changeInfo(RW_REALIZED|RW_REALIZING, RW_FUTURE);
    } else {
        // Normal class. Allocate writeable class data.
        rw = (class_rw_t *)calloc(sizeof(class_rw_t), 1);
        rw->ro = ro;
        rw->flags = RW_REALIZED|RW_REALIZING;
        cls->setData(rw);
    }
    ....
}
```
ro = (const class_ro_t *)cls->data();可以看出类的初始信息其实本来是存储在 class_ro_t中的，并且ro本来是指向cls->data()，也就是bits.data()得到的是ro.但是在运行过程中创建了 class_rw_t，并且将cls->data指向 rw，同时将初始信息ro赋值给rw中的ro。最后通过setData(rw)设置data。那么此时bits.data()得到的就是rw,之后再去检查是否有分类，同时将分类的方法，属性，协议列表整合存储在class_rw_t的方法，属性，及协议列表中。

*****

# Class_rw_t中如何存储方法的

## method_t

我们知道在method_array_t最终存储的是method_t，method_t是对方法函数的封装，每一个方法对象就是一个method_t.通过源码来查看method_t结构：

```php
struct method_t {
    SEL name;
    const char *types;
    IMP imp;

    struct SortBySELAddress :
        public std::binary_function<const method_t&,
                                    const method_t&, bool>
    {
        bool operator() (const method_t& lhs,
                         const method_t& rhs)
        { return lhs.name < rhs.name; }
    };
};
```
### 1.SEL

SEL代表方法/函数名，一般叫做选择器，底层结构跟char* 类似,typedef struct objc_selector * SEL,可以把SEL看做是方法名字符串。

```php
typedef struct objc_selector *SEL;

猜测,runtime源码没有
struct objc_selector  {
    char name[64 or ...];
    ...
};

```

SEL可以通过@selector()和sel_registerName()获得

```php
SEL sel1 = @selector(test);
SEL sel2 = sel_registerName("test");
```






