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

---

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

也可以通过**sel_getName**和**NSStringFromSelector**将SEL转换为字符串

```php
char *string = sel_getName(sel1);
NSString *string2 = NSStringFromSelector(sel2);
```

不同类中相同名字的方法，所对应的方法选择器是相同的。

```php
NSLog(@"%p,%p", sel1,sel2);
Runtime-test[23738:8888825] 0x1017718a3,0x1017718a3
```

**⚠️SEL仅仅代表方法的名字，并且不同类中相同的方法名的SEL是全局唯一的**

### 2.types

**types**包含了函数返回值，参数编码的字符串。通过字符串拼接的方式将返回值和参数拼接成了一个字符串，来代表函数返回值和参数。

我们通过代码来检查下types是如何代表函数及返回值的，首先通过模拟Class的内部实现，通过强制转换：

```php
Person *person = [[Person alloc] init];
xx_objc_class *cls = (__bridge xx_objc_class *)[Person class];
class_rw_t *data = cls->data();
```

通过断点查看types具体内容：

![types](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-1.png)

从上图中我们可以看出：**types**的值为[v16@0:8](),那么这个值代表什么？apple有一个详细的对照表：

![types](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-2.png)

我们将types的值和表进行一一对应：

```php
- (void) test;

 v    16      @     0     :     8
void         id          SEL
// 16表示参数的占用空间大小，id后面跟的0表示从0位开始存储，id占8位空间。
// SEL后面的8表示从第8位开始存储，SEL同样占8位空间
```

我们知道任何方法都有两个默认的参数：**id类型的self**和**SEL类型的_cmd**,下面我们为test方法添加参数和返回值：

![back](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-3.png)

同样我们根据表进行一个对应：

```php
- (int)testWithAge:(int)age Height:(float)height
{
    return 0;
}
  i    24    @    0    :    8    i    16    f    20
int         id        SEL       int        float
// 参数的总占用空间为 8 + 8 + 4 + 4 = 24
// id 从第0位开始占据8位空间
// SEL 从第8位开始占据8位空间
// int 从第16位开始占据4位空间
// float 从第20位开始占据4位空间
```

⚠️iOS提供了[@encode]()指令，可以将具体的类型转化为字符串编码：

```
NSLog(@"%s",@encode(int));
NSLog(@"%s",@encode(float));
NSLog(@"%s",@encode(id));
NSLog(@"%s",@encode(SEL));

// 打印内容
Runtime-test[25275:9144176] i
Runtime-test[25275:9144176] f
Runtime-test[25275:9144176] @
Runtime-test[25275:9144176] :
```

### 3. IMP

[IMP]()代表了函数的具体实现，存储的内容是`函数地址`。也就是说找到`imp`就可以找到函数实现，进而对函数实现调用。






























































































