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

我们根据上述的代码打印`IMP`的值：

```
Printing description of data->methods->first.imp:
(IMP) imp = 0x000000010c66a4a0 (Runtime-test`-[Person testWithAge:Height:] at Person.m:13)
```

然后在`test`方法内部打断点，并且查看方法的内部`imp`中存储的地址就是方法实现的地址。

![test](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-4.png)

上面分析源码可以知道，方法列表是如何存储在**Class类对象**的，但是当有多次继承之后想要调用基类的方法的时候，就需要通过 **supperClass** 指针一层一层的找到基类，在从基类的方法列表中找到对应的方法进行调用。如果多次调用基类方法，那么就需要多次进行遍历每一层父类的方法列表，这是一个很大的性能问题。

apple进行了一套方法缓存策略：

## 方法缓存策略 cache_t

我们再看下 **类对象** 的结构，成员变量 **cache** 就是用来对方法进行缓存的。

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
```

**`[cache_t cache]`  用来缓存曾经使用多的方法，提高方法的查找速度**



回顾方法的调用过程：`调用方法的时候，需要去类对象的方法列表里面进行遍历。如果方法不在列表里面，就会通过` [supperClass]() `找到父类的类对象，然后在父类的类对象的方法列表里面查找`

如果方法需要调用很多次的话，那就相当于每次调用都需要进行一次遍历，为了快速查找方法，使用了 **cache__t**

每次调用方法的时候，会先去cache_t中查找有没有进行缓存，没有再去类对象进行查找，在类对象中找到会后缓存到 `cache__t`中

### 1.cache_t是如何进行缓存的

首先来看下 `cache_t`的代码结构：

```php
struct cache_t {
    struct bucket_t *_buckets; //散列表，数组
    mask_t _mask;  //散列表的长度
    mask_t _occupied; //已经缓存的方法数量
};
```

`bucket_t`是以数组的方式存储方法散列表的，看下`bucket_t`的内部结构

```php
struct bucket_t {
private:
    cache_key_t _key; //SEL作为key
    IMP _imp; //函数的内存地址

public:
    inline cache_key_t key() const { return _key; }
    inline IMP imp() const { return (IMP)_imp; }
    inline void setKey(cache_key_t newKey) { _key = newKey; }
    inline void setImp(IMP newImp) { _imp = newImp; }

    void set(cache_key_t newKey, IMP newImp);
};
```

从上面的代码可以知道`bucket_t`存储着`SEL`和`_imp`，通过`key->vlaue`的形式，以`Sel`为`key`,函数的内存地址`_imp`为`value`进行存储

![cache_t](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-5.png)

上面的 **bucket_t** 成为 **散列表（哈希表）**

⚠️`散列表（Hash table)是根据关键码值（Key-Vaule）而直接进行访问的数据结构。也就是说，它是通过把关键码值映射到表中的一个位置来访问，以加快查找的速度。这个映射函数叫做散列函数，存放记录的数组叫做散列表`

## 散列函数及散列表原理

### 1.cache_fill & cache_fill_nolock函数

```php
void cache_fill(Class cls, SEL sel, IMP imp, id receiver)
{
#if !DEBUG_TASK_THREADS
    mutex_locker_t lock(cacheUpdateLock);
    cache_fill_nolock(cls, sel, imp, receiver);
#else
    _collecting_in_critical();
    return;
#endif
}

static void cache_fill_nolock(Class cls, SEL sel, IMP imp, id receiver)
{
    cacheUpdateLock.assertLocked();
    // 如果没有initialize直接return
    if (!cls->isInitialized()) return;
    // 确保线程安全，没有其他线程添加缓存
    if (cache_getImp(cls, sel)) return;
    // 通过类对象获取到cache 
    cache_t *cache = getCache(cls);
    // 将SEL包装成Key
    cache_key_t key = getKey(sel);
   // 占用空间+1
    mask_t newOccupied = cache->occupied() + 1;
   // 获取缓存列表的缓存能力，能存储多少个键值对
    mask_t capacity = cache->capacity();
    if (cache->isConstantEmptyCache()) {
        // 如果为空的，则创建空间，这里创建的空间为4个。
        cache->reallocate(capacity, capacity ?: INIT_CACHE_SIZE);
    }
    else if (newOccupied <= capacity / 4 * 3) {
        // 如果所占用的空间占总数的3/4一下，则继续使用现在的空间
    }
    else {
       // 如果占用空间超过3/4则扩展空间
        cache->expand();
    }
    // 通过key查找合适的存储空间。
    bucket_t *bucket = cache->find(key, receiver);
    // 如果key==0则说明之前未存储过这个key，占用空间+1
    if (bucket->key() == 0) cache->incrementOccupied();
    // 存储key，imp 
    bucket->set(key, imp);
}
```

### 2.reallocate函数

通过上面的源代码我们知道 **reallocate** 函数负责分配散列表空间：

```php
void cache_t::reallocate(mask_t oldCapacity, mask_t newCapacity)
{
    // 旧的散列表能否被释放
    bool freeOld = canBeFreed();
    // 获取旧的散列表
    bucket_t *oldBuckets = buckets();
    // 通过新的空间需求量创建新的散列表
    bucket_t *newBuckets = allocateBuckets(newCapacity);

    assert(newCapacity > 0);
    assert((uintptr_t)(mask_t)(newCapacity-1) == newCapacity-1);
    // 设置Buckets和Mash，Mask的值为散列表长度-1
    setBucketsAndMask(newBuckets, newCapacity - 1);
    // 释放旧的散列表
    if (freeOld) {
        cache_collect_free(oldBuckets, oldCapacity);
        cache_collect(false);
    }
}

```

上面的代码中 **reallocate** 函数的 **newCapacity** 为 **INIT_CACHE_SIZE** ，INIT_CACHE_SIZE是个枚举值，也就是4。因此散列表初始创建的空间只有4个。

```php
enum {
    INIT_CACHE_SIZE_LOG2 = 2,
    INIT_CACHE_SIZE      = (1 << INIT_CACHE_SIZE_LOG2)
};
```

### expand()函数

当散列表的空间被超过3/4的时候，散列表会使用 **expand()** 函数进行扩展，下面是expend()函数：

```php
void cache_t::expand()
{
    cacheUpdateLock.assertLocked();
    // 获取旧的散列表的存储空间
    uint32_t oldCapacity = capacity();
    // 将旧的散列表存储空间扩容至两倍
    uint32_t newCapacity = oldCapacity ? oldCapacity*2 : INIT_CACHE_SIZE;
    // 为新的存储空间赋值
    if ((uint32_t)(mask_t)newCapacity != newCapacity) {
        newCapacity = oldCapacity;
    }
    // 调用reallocate函数，重新创建存储空间
    reallocate(oldCapacity, newCapacity);
}
```

上面的代码会将散列表空间扩容之前的两倍。

### 3.find 函数

最后来看一下散列表中是如何快速通过 **key** 找到相应的 **bucket** ？find函数：

```php
bucket_t * cache_t::find(cache_key_t k, id receiver)
{
    assert(k != 0);
    // 获取散列表
    bucket_t *b = buckets();
    // 获取mask
    mask_t m = mask();
    // 通过key找到key在散列表中存储的下标
    mask_t begin = cache_hash(k, m);
    // 将下标赋值给i
    mask_t i = begin;
    // 如果下标i中存储的bucket的key==0说明当前没有存储相应的key，将b[i]返回出去进行存储
    // 如果下标i中存储的bucket的key==k，说明当前空间内已经存储了相应key，将b[i]返回出去进行存储
    do {
        if (b[i].key() == 0  ||  b[i].key() == k) {
            // 如果满足条件则直接reutrn出去
            return &b[i];
        }
    // 如果走到这里说明上面不满足，那么会往前移动一个空间重新进行判定，知道可以成功return为止
    } while ((i = cache_next(i, m)) != begin);

    // hack
    Class cls = (Class)((uintptr_t)this - offsetof(objc_class, cache));
    cache_t::bad_cache(receiver, (SEL)k, cls);
}
```

函数cache_hash(key,value)是通过key找到方法在散列表存储的下标，看下函数的内部：

```php
static inline mask_t cache_hash(cache_key_t key, mask_t mask) 
{
    return (mask_t)(key & mask);
}
```

可以发现cache_hash（k,m）函数内部仅仅是进行了 **key & mask** 的按位与运算，得到下标即存储在相应的位置上。

### 4._mask

__mask 的值是散列表的长度减一，那么任何通过与 _mask 进行按位运算之后获得的值都会小于等于 _mask:比如：

```php
  0101 1011  // 任意值
& 0000 0111  // mask = 7
------------
  0000 0011 //获取的值始终等于或小于mask的值
```

## 总结

当第一次使用方法时，消息机制通过 **isa** 找到方法之后，会对方法以 **<SEL:IMP>** 的方式缓存在 `cache` 的`_buckets` 中，当第一次存储的时候，会创建具有4个空间的散列表，并将 `_mask`的位置为散列表的长度减一，之后通过 `SEL&mask` 计算出方法存储的小标值，并将方法存储在散列表中。举个例子，如果计算出下标值为3，那么就将方法直接存储在下标为3的空间中，前面的空间会留空。

当散列表中存储的方法占据散列表长度超过3/4的时候，散列表会进行扩容操作，将创建一个新的散列表并且空间扩容到原来的两倍，并重置`mask`的值，最后释放旧的散列表，此时再有方法进行缓存的话，需要重新通过 `SEL&mask`计算出下标再按照新的下标进行存储。

如果一个类中方法很多，其中很可能会出现多个方法的`SEL & mask`是同一个下标值，那么会调用`cache_next`函数忘下标值-1的地方进行存储，如果下标值-1的空间中存储有方法，并且`key`不与要存储的`key`相同，那么再到前面一位进行比较，直到找到一位空间没有存放方法或者key与要存储的key相同为止，如果到下标0的话就会到下标为`mask`的空间也就是最大空间进行对比。

当要查找方法时，并不需要遍历散列表，同样通过`SEL & mask`计算出下标，直接去下标值的空间取值即可，同上，如果下标值中存储的`key`与要查找的`key`不相同，就去前一位查找，这样虽然占用了少量的空间，但是大大节省了时间，也就是**使用空间换取存储的时间**

查找流程：

![find](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-6.png)

---

# 验证方法缓存读取流程

我们根据强制转换类：

```php
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        CollegeStudent *collegeStudent = [[CollegeStudent alloc] init];
        xx_objc_class *collegeStudentClass = (__bridge xx_objc_class *)[CollegeStudent class];
        
        cache_t cache = collegeStudentClass->cache;
        bucket_t *buckets = cache._buckets;
        
        [collegeStudent personTest];
        [collegeStudent studentTest];
        
        NSLog(@"----------------------------");
        for (int i = 0; i <= cache._mask; i++) {
            bucket_t bucket = buckets[i];
            NSLog(@"%s %p", bucket._key, bucket._imp);
        }
        NSLog(@"----------------------------");
        
        [collegeStudent colleaeStudentTest];

        cache = collegeStudentClass->cache;
        buckets = cache._buckets;
        NSLog(@"----------------------------");
        for (int i = 0; i <= cache._mask; i++) {
            bucket_t bucket = buckets[i];
            NSLog(@"%s %p", bucket._key, bucket._imp);
        }
        NSLog(@"----------------------------");
        
        NSLog(@"%p",@selector(colleaeStudentTest));
        NSLog(@"----------------------------");
    }
    return 0;
}
```

我们分别在`collegeStudent`实例对象调用`personTest` ,`studentTest`,`collegeStudentTest`方法出打断点进行查看`cache`的变化。

#### 1.`personTest` 方法调用之前：

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-7.png)

从上图中看出，`personTest`方法调用之前，`cache`中仅仅存储了`init`方法，上图可以看出`init`方法恰好存储在下标为0的位置，因此我们可以看出，`_mask`的值为3.验证了我们再上门提到的散列表第一次存储时会分配4个内存空间，`_occupied`值为1说明了此时仅仅缓存了一个方法。

当`collegeStudent`在调用`personTest`的时候，首先发现`collegeStudent`的`cache`中没有`personTest`方法，就会去`collegeStudent`类对象的方法列表里面查找，方法列表中也没有，那么根据`supperClass`指针找到`student`类对象，`student`类对象的缓存和方法列表中也没有，再通过`supperClass`指针找到`person`类对象，最终在`Person`类对象的方法列表中找到进行调用，并缓存在`collegeStudent`类对象的缓存中。

#### 2.执行personTest方法：

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-8.png)

上面的代码发现`_occupied`值为2，说明了此时`personTest`方法已经缓存在了`collegeStudent`类对象的`cache`中

同理执行：`studentTest`:我们看下`cache`

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-9.png)

从上图中看出`cache`确实存储了`init`，`personTest`,`studentTest`三个方法。

那么执行`collegeStudentTest`方法只后，此时`cache`中应该对`collegeStudentTest`方法进行缓存，上面我们知道当存储的方法抄错散列表3/4时，就需要创建一个是原来两倍的散列表。调用`collegeStudentTest`重新打印`cache`：

![a](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime2-10.png)

从上图看出，`_bucket`散列表扩容之后仅仅存储了`collegeStudentTest`方法，并且对`SEL & mask`进行位运算得出的下标正好是`_bucket`找中`collegeStudentTest`方法存储的位置。
































































