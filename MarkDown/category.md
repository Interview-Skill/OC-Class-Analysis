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

```php
struct category_t {
    const char *name;
    classref_t cls;
    struct method_list_t *instanceMethods; // 对象方法
    struct method_list_t *classMethods; // 类方法
    struct property_list_t *protocols; // 协议
    struct property_list_t *instanceProperties; // 属性
    // Fields below this point are not always present on disk.
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};

```
从Category定义的结构体中我们可以找到平时使用的对象方法，类方法，协议和属性的存储方式。<strong>可以看出并没有成员变量的存储方式，因此是不可以
添加成员变量的，在Category中添加属性，只是生成了set/get方法而已，具体还需要自己实现</strong>

我们继续查看method_list_t、property_list_t、property_list_t具体是什么？
##### _CATEGORY_CLASS_METHODS_CategoryPerson_ 类方法list
```php
static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[1];
} _OBJC_$_CATEGORY_CLASS_METHODS_CategoryPerson_$_Test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	1,
	{{(struct objc_selector *)"abc", "v16@0:8", (void *)_C_CategoryPerson_Test_abc}}
};
```

#### _CATEGORY_INSTANCE_METHODS_CategoryPerson_ 你在Category定义的对象方法

```php

static struct /*_method_list_t*/ {
	unsigned int entsize;  // sizeof(struct _objc_method)
	unsigned int method_count;
	struct _objc_method method_list[3];
} _OBJC_$_CATEGORY_INSTANCE_METHODS_CategoryPerson_$_Test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_objc_method),
	3,
	{{(struct objc_selector *)"test", "v16@0:8", (void *)_I_CategoryPerson_Test_test},
	{(struct objc_selector *)"setAge:", "v20@0:8i16", (void *)_I_CategoryPerson_Test_setAge_},
	{(struct objc_selector *)"age", "i16@0:8", (void *)_I_CategoryPerson_Test_age}}
};
```

#### _OBJC_CATEGORY_PROTOCOLS_ 协议list
```php
static struct /*_protocol_list_t*/ {
	long protocol_count;  // Note, this is 32/64 bit
	struct _protocol_t *super_protocols[1];
} _OBJC_CATEGORY_PROTOCOLS_$_CategoryPerson_$_Test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	1,
	&_OBJC_PROTOCOL_NSCopying
};
```

#### _PROP_LIST_CategoryPerson_ 属性list
```php 
static struct /*_prop_list_t*/ {
	unsigned int entsize;  // sizeof(struct _prop_t)
	unsigned int count_of_properties;
	struct _prop_t prop_list[1];
} _OBJC_$_PROP_LIST_CategoryPerson_$_Test __attribute__ ((used, section ("__DATA,__objc_const"))) = {
	sizeof(_prop_t),
	1,
	{{"age","Ti,N"}}
};
```

可以看到上面的结构体的定义和我们写的Category中是一一对应的。

再来看一个对应关系：
```php
///OC Person.m编译为c++结构
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
//定义的Persong的Category
extern "C" __declspec(dllimport) struct _class_t OBJC_CLASS_$_CategoryPerson;

static struct _category_t _OBJC_$_CATEGORY_CategoryPerson_$_Test __attribute__ ((used, section ("__DATA,__objc_const"))) = 
{
	"CategoryPerson",
	0, // &OBJC_CLASS_$_CategoryPerson,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_INSTANCE_METHODS_CategoryPerson_$_Test,
	(const struct _method_list_t *)&_OBJC_$_CATEGORY_CLASS_METHODS_CategoryPerson_$_Test,
	(const struct _protocol_list_t *)&_OBJC_CATEGORY_PROTOCOLS_$_CategoryPerson_$_Test,
	(const struct _prop_list_t *)&_OBJC_$_PROP_LIST_CategoryPerson_$_Test,
};
static void OBJC_CATEGORY_SETUP_$_CategoryPerson_$_Test(void ) {
	_OBJC_$_CATEGORY_CategoryPerson_$_Test.cls = &OBJC_CLASS_$_CategoryPerson;
}
```
可以看到_OBJC_$_CATEGORY_CategoryPerson_$_Test 就是对应定义的_class_t,_OBJC_$_CATEGORY_CategoryPerson_$_Test.cls = &OBJC_CLASS_$_CategoryPerson;在这里将_OBJC_$_CATEGORY_CategoryPerson_$_Test的cls指向 OBJC_CLASS_$_CategoryPerson

上面就是Category的一个完整的定义；我们继续探究catetory_t存储的方法、属性、协议是如何添加到类对象中的。

### 探究catetory_t存储的方法、属性、协议是添加到类对象中

#### 1.查看runtime初始化函数：
```php
/***********************************************************************
* _objc_init
* Bootstrap initialization. Registers our image notifier with dyld.
* Called by libSystem BEFORE library initialization time
**********************************************************************/

void _objc_init(void)
{
    static bool initialized = false;
    if (initialized) return;
    initialized = true;
    
    // fixme defer initialization until an objc-using image is found?
    environ_init();
    tls_init();
    static_init();
    lock_init();
    exception_init();

    _dyld_objc_notify_register(&map_images, load_images, unmap_image);// 这里我们dyld动态加载器会去加载images
}
```
我们接下来找&map_iamges读取模块（images代表模块）,在map_images_nolock中找到_read_images函数，在read_iamges中找到分类有关的函数：

#### 2. read_images dyld link 模块

```php
// Discover categories. 
for (EACH_HEADER) {
    category_t **catlist = 
        _getObjc2CategoryList(hi, &count);
    bool hasClassProperties = hi->info()->hasCategoryClassProperties();

    for (i = 0; i < count; i++) {
        category_t *cat = catlist[i];
        Class cls = remapClass(cat->cls);

        if (!cls) {
            // Category's target class is missing (probably weak-linked).
            // Disavow any knowledge of this category.
            catlist[i] = nil;
            if (PrintConnecting) {
                _objc_inform("CLASS: IGNORING category \?\?\?(%s) %p with "
                             "missing weak-linked target class", 
                             cat->name, cat);
            }
            continue;
        }

        // Process this category. 
        // First, register the category with its target class. 
        // Then, rebuild the class's method lists (etc) if 
        // the class is realized. 
        bool classExists = NO;
        if (cat->instanceMethods ||  cat->protocols  
            ||  cat->instanceProperties) 
        {
            addUnattachedCategoryForClass(cat, cls, hi);
            if (cls->isRealized()) {
                remethodizeClass(cls);
                classExists = YES;
            }
            if (PrintConnecting) {
                _objc_inform("CLASS: found category -%s(%s) %s", 
                             cls->nameForLogging(), cat->name, 
                             classExists ? "on existing class" : "");
            }
        }

        if (cat->classMethods  ||  cat->protocols  
            ||  (hasClassProperties && cat->_classProperties)) 
        {
            addUnattachedCategoryForClass(cat, cls->ISA(), hi);
            if (cls->ISA()->isRealized()) {
                remethodizeClass(cls->ISA());
            }
            if (PrintConnecting) {
                _objc_inform("CLASS: found category +%s(%s)", 
                             cls->nameForLogging(), cat->name);
            }
        }
    }
}
```

仔细的阅读这段代码，作用是来查找有没有分类的。通过_getObjc2CategoryList获取分类列表，进行遍历，获取其中的方法、协议、属性。最后调用<strong>remethodizeClass(cls)函数；

#### 3. remethodizeClass
    
```php

/***********************************************************************
* remethodizeClass
* Attach outstanding categories to an existing class.
* Fixes up cls's method list, protocol list, and property list.
* Updates method caches for cls and its subclasses.
* Locking: runtimeLock must be held by the caller
**********************************************************************/
static void remethodizeClass(Class cls)
{
    category_list *cats;
    bool isMeta;

    runtimeLock.assertWriting();

    isMeta = cls->isMetaClass();

    // Re-methodizing: check for more categories
    if ((cats = unattachedCategoriesForClass(cls, false/*not realizing*/))) {
        if (PrintConnecting) {
            _objc_inform("CLASS: attaching categories to class '%s' %s", 
                         cls->nameForLogging(), isMeta ? "(meta)" : "");
        }
        
        attachCategories(cls, cats, true /*flush caches*/);        
        free(cats);
    }
}
```
从上面的代码我们看到最后是调用了AttachCategories函数，这个函数参数是类对象cls和分类数组cats；因为分类可以有多个，所以分类信息保存在category_t接头中，多个分类保存在category_list中；

#### 4. attachCategories 开始给对象的类添加Category中的信息
```php
// Attach method lists and properties and protocols from categories to a class.
// Assumes the categories in cats are all loaded and sorted by load order, 
// oldest categories first.
static void 
attachCategories(Class cls, category_list *cats, bool flush_caches)
{
    if (!cats) return;
    if (PrintReplacedMethods) printReplacements(cls, cats);

    bool isMeta = cls->isMetaClass();

    // fixme rearrange to remove these intermediate allocations
    // 根据分类中的属性方法、属性、协议来分配内存
    method_list_t **mlists = (method_list_t **)
        malloc(cats->count * sizeof(*mlists));
    property_list_t **proplists = (property_list_t **)
        malloc(cats->count * sizeof(*proplists));
    protocol_list_t **protolists = (protocol_list_t **)
        malloc(cats->count * sizeof(*protolists));

    // Count backwards through cats to get newest categories first
    int mcount = 0;
    int propcount = 0;
    int protocount = 0;
    int i = cats->count;
    bool fromBundle = NO;
    while (i--) {
        auto& entry = cats->list[i];//通过遍历去拿每一个分类

        method_list_t *mlist = entry.cat->methodsForMeta(isMeta);
        if (mlist) {
            mlists[mcount++] = mlist;
            fromBundle |= entry.hi->isBundle();//将一个类的所有分类的方法存到mlist数组中；
        }

        property_list_t *proplist = 
            entry.cat->propertiesForMeta(isMeta, entry.hi);
        if (proplist) {
            proplists[propcount++] = proplist; //将一个类的所有分类的属性存到proplists
        }

        protocol_list_t *protolist = entry.cat->protocols;
        if (protolist) {
            protolists[protocount++] = protolist;//将一个类的所有的分类的协议方法存储到protolist
        }
    }

    auto rw = cls->data();//rw：class_rw_t结构体；class结构体中用来存储类对象的属性方法，协议和属性

    prepareMethodLists(cls, mlists, mcount, NO, fromBundle);
    rw->methods.attachLists(mlists, mcount);//将分类的方法，协议，属性传递给rw对应的函数
    free(mlists);
    if (flush_caches  &&  mcount > 0) flushCaches(cls);

    rw->properties.attachLists(proplists, propcount);
    free(proplists);

    rw->protocols.attachLists(protolists, protocount);
    free(protolists);
}
```
上述源码中可以看出，首先根据方法列表，属性列表，协议列表，malloc分配内存，根据多少个分类以及每一块方法需要多少内存来分配相应的内存地址。之后从分类数组里面往三个数组里面存放分类数组里面存放的分类方法，属性以及协议放入对应mlist、proplists、protolosts数组中，这三个数组放着所有分类的方法，属性和协议。
之后通过类对象的data()方法，拿到类对象的class_rw_t结构体rw，在class结构中我们介绍过，class_rw_t中存放着类对象的方法，属性和协议等数据，rw结构体通过类对象的data方法获取，所以rw里面存放这类对象里面的数据。
之后分别通过rw调用方法列表、属性列表、协议列表的attachList函数，将所有的分类的方法、属性、协议列表数组传进去，我们大致可以猜想到在attachList方法内部将分类和本类相应的对象方法，属性，和协议进行了合并。
#### attachList方法
```php
void attachLists(List* const * addedLists, uint32_t addedCount) {
if (addedCount == 0) return;

if (hasArray()) {
    // many lists -> many lists
    uint32_t oldCount = array()->count; //原来
    uint32_t newCount = oldCount + addedCount;
    setArray((array_t *)realloc(array(), array_t::byteSize(newCount)));
    array()->count = newCount;
    memmove(array()->lists + addedCount, array()->lists, 
	    oldCount * sizeof(array()->lists[0]));
    memcpy(array()->lists, addedLists, 
	   addedCount * sizeof(array()->lists[0]));
}
else if (!list  &&  addedCount == 1) {
    // 0 lists -> 1 list
    list = addedLists[0];
} 
else {
    // 1 list -> many lists
    List* oldList = list;
    uint32_t oldCount = oldList ? 1 : 0;
    uint32_t newCount = oldCount + addedCount;
    setArray((array_t *)malloc(array_t::byteSize(newCount)));
    array()->count = newCount;
    if (oldList) array()->lists[addedCount] = oldList;
    memcpy(array()->lists, addedLists, 
	   addedCount * sizeof(array()->lists[0]));
   }
}
```
上述源代码中有两个重要的数组
> array()->lists： 类对象原来的方法列表，属性列表，协议列表。<br>
> addedLists：传入所有分类的方法列表，属性列表，协议列表。<br>
> attachLists函数中最重要的两个方法为memmove内存移动和memcpy内存拷贝。我们先来分别看一下这两个函数<br>

```php
// memmove ：内存移动。
/*  __dst : 移动内存的目的地
*   __src : 被移动的内存首地址
*   __len : 被移动的内存长度
*   将__src的内存移动__len块内存到__dst中
*/
void    *memmove(void *__dst, const void *__src, size_t __len);

// memcpy ：内存拷贝。
/*  __dst : 拷贝内存的拷贝目的地
*   __src : 被拷贝的内存首地址
*   __n : 被移动的内存长度
*   将__src的内存移动__n块内存到__dst中
*/
void    *memcpy(void *__dst, const void *__src, size_t __n);

```
1. 在没有经过内存移动和copy：
![memmove](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/array-list.png)

2. 经过memmove之后，内存变化：
```php
// array()->lists 原来方法、属性、协议列表数组
// addedCount 分类数组长度
// oldCount * sizeof(array()->lists[0]) 原来数组占据的空间
memmove(array()->lists + addedCount, array()->lists, 
                  oldCount * sizeof(array()->lists[0]));

```
![memmove](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/array-copy.png)

3. 经过memcpy方法之后，内存的变化
```php
// array()->lists 原来方法、属性、协议列表数组
// addedLists 分类方法、属性、协议列表数组
// addedCount * sizeof(array()->lists[0]) 原来数组占据的空间
memcpy(array()->lists, addedLists, 
               addedCount * sizeof(array()->lists[0]));

```
![memmove](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/array-move.png)




























