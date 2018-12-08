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
#### 5.attachList方法
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

可以看到之前的指针并没有改变，至始至终都指向开头的位置。并且经过了memmove和memcpy之后，分类的方法，属性，协议被放到了类对象原本的方法，属性，协议列表前面。
<br>
<strong>‼️为什么将分类的方法追加到本来的对象方法列表的前面呢？这样做是为了保证分类方法优先调用。我们一般认为分类重写本类方法的时候，会覆盖本类的方法，
其实并不是覆盖，只是优先调用，本类的方法仍然在内存中。</strong><br>
下面我们验证下分类不是覆盖本类方法，只是优先调用：打印所有类的所有方法：
```php

- (void)printMethodNamesOfClass:(Class)cls
{
    unsigned int count;
    // 获得方法数组
    Method *methodList = class_copyMethodList(cls, &count);
    // 存储方法名
    NSMutableString *methodNames = [NSMutableString string];
    // 遍历所有的方法
    for (int i = 0; i < count; i++) {
        // 获得方法
        Method method = methodList[i];
        // 获得方法名
        NSString *methodName = NSStringFromSelector(method_getName(method));
        // 拼接方法名
        [methodNames appendString:methodName];
        [methodNames appendString:@", "];
    }
    // 释放
    free(methodList);
    // 打印方法名
    NSLog(@"%@ - %@", cls, methodNames);
}
- (void)viewDidLoad {
    [super viewDidLoad];    
    Preson *p = [[Preson alloc] init];
    [p run];
    [self printMethodNamesOfClass:[Preson class]];
}

```
> 2018-12-06 20:31:57.162771+0800 iOS底层原理总结[49992:3220836] person (test2) run<br>
2018-12-06 20:31:57.162918+0800 iOS底层原理总结[49992:3220836] CategoryPerson - test--- run--- run--- setAge:--- age---

## 总结：
### Q:Category的实现原理？以及为什么Category中只能添加方法不能添加属性？

A:Category的实现原理就是将Category中的对象方法，协议，属性存放到category_t结构体中，然后将结构体中的方法列表拷贝到类对象的方法列表中。<br>
Category中可以添加属性，但是不能帮你自动生成成员变量和get/set方法。因为在category_t结构体中并不存在成员变量。而且前面分析，‼️成员变量是存在实例对象里面的，这个是在编译的时候就已经决定的。而分类是在运行时才去加载的。所以我们无法再程序运行的时候讲分类的成员变量添加到实例对象的结构体中。因此说分类不可以添加实例变量。

### load 和 Initialize函数：

#### 1.‼️load函数式在程序启动就会调用：当加载类信息的时候就调用：

```php
//首先是在加载image的时候
void
load_images(const char *path __unused, const struct mach_header *mh)
{
    // Return without taking locks if there are no +load methods here.
    if (!hasLoadMethods((const headerType *)mh)) return;

    recursive_mutex_locker_t lock(loadMethodLock);

    // Discover load methods
    {
        rwlock_writer_t lock2(runtimeLock);
        prepare_load_methods((const headerType *)mh);
    }

    // Call +load methods (without runtimeLock - re-entrant)
    call_load_methods();
}
//prepare_load_methods
void prepare_load_methods(const headerType *mhdr)
{
    size_t count, i;

    runtimeLock.assertWriting();

    classref_t *classlist = 
        _getObjc2NonlazyClassList(mhdr, &count);
    for (i = 0; i < count; i++) {
        schedule_class_load(remapClass(classlist[i]));
    }

    category_t **categorylist = _getObjc2NonlazyCategoryList(mhdr, &count);
    for (i = 0; i < count; i++) {
        category_t *cat = categorylist[i];
        Class cls = remapClass(cat->cls);
        if (!cls) continue;  // category for ignored weak-linked class
        realizeClass(cls);
        assert(cls->ISA()->isRealized());
        add_category_to_loadable_list(cat);
    }
}
//这里我们看到有个加载所有的load方法：
call_load_methods
/***********************************************************************
* call_load_methods
* Call all pending class and category +load methods.
* Class +load methods are called superclass-first. 
* Category +load methods are not called until after the parent class's +load.
* 
* This method must be RE-ENTRANT, because a +load could trigger 
* more image mapping. In addition, the superclass-first ordering 
* must be preserved in the face of re-entrant calls. Therefore, 
* only the OUTERMOST call of this function will do anything, and 
* that call will handle all loadable classes, even those generated 
* while it was running.
*
* The sequence below preserves +load ordering in the face of 
* image loading during a +load, and make sure that no 
* +load method is forgotten because it was added during 
* a +load call.
* Sequence:
* 1. Repeatedly call class +loads until there aren't any more
* 2. Call category +loads ONCE.
* 3. Run more +loads if:
*    (a) there are more classes to load, OR
*    (b) there are some potential category +loads that have 
*        still never been attempted.
* Category +loads are only run once to ensure "parent class first" 
* ordering, even if a category +load triggers a new loadable class 
* and a new loadable category attached to that class. 
*
* Locking: loadMethodLock must be held by the caller 
*   All other locks must not be held.
**********************************************************************/
void call_load_methods(void)
{
    static bool loading = NO;
    bool more_categories;

    loadMethodLock.assertLocked();

    // Re-entrant calls do nothing; the outermost call will finish the job.
    if (loading) return;
    loading = YES;

    void *pool = objc_autoreleasePoolPush();

    do {
        // 1. Repeatedly call class +loads until there aren't any more
        while (loadable_classes_used > 0) {
            call_class_loads();//这里可以看到先调用类的load函数，后调用分类的
        }

        // 2. Call category +loads ONCE
        more_categories = call_category_loads();

        // 3. Run more +loads if there are classes OR more untried categories
    } while (loadable_classes_used > 0  ||  more_categories);

    objc_autoreleasePoolPop(pool);

    loading = NO;
}
/***********************************************************************
* call_class_loads
* Call all pending class +load methods.
* If new classes become loadable, +load is NOT called for them.
*
* Called only by call_load_methods().
**********************************************************************/
static void call_class_loads(void)
{
    int i;
    
    // Detach current loadable list.
    struct loadable_class *classes = loadable_classes;
    int used = loadable_classes_used;
    loadable_classes = nil;
    loadable_classes_allocated = 0;
    loadable_classes_used = 0;
    
    // Call all +loads for the detached list.
    for (i = 0; i < used; i++) {
        Class cls = classes[i].cls;
        load_method_t load_method = (load_method_t)classes[i].method;//******重点这里是直接通过内存地址调用的
        if (!cls) continue; 

        if (PrintLoading) {
            _objc_inform("LOAD: +[%s load]\n", cls->nameForLogging());
        }
        (*load_method)(cls, SEL_load);
    }
    
    // Destroy the detached list.
    if (classes) free(classes);
}

```

> 这里可以看出：先调用类的load函数后调用分类的；下面我们通过代码验证：
```php
2018-12-06 21:06:55.164044+0800 iOS底层原理总结[56809:3273926] Class Load
2018-12-06 21:06:55.164670+0800 iOS底层原理总结[56809:3273926] Class subClass load
2018-12-06 21:06:55.164743+0800 iOS底层原理总结[56809:3273926] Class catetory load

<strong>调用顺序：父类->子类->分类
``` 

#### 2. initialize方法
源码在objc_initialize.mm中
```php
/***********************************************************************
* class_initialize.  Send the '+initialize' message on demand to any
* uninitialized class. Force initialization of superclasses first.
**********************************************************************/
void _class_initialize(Class cls)
{
    assert(!cls->isMetaClass());

    Class supercls;
    bool reallyInitialize = NO;

    // Make sure super is done initializing BEFORE beginning to initialize cls.
    // See note about deadlock above.
    supercls = cls->superclass;
    if (supercls  &&  !supercls->isInitialized()) {
        _class_initialize(supercls);
    }
    
    // Try to atomically set CLS_INITIALIZING.
    {
        monitor_locker_t lock(classInitLock);
        if (!cls->isInitialized() && !cls->isInitializing()) {
            cls->setInitializing();
            reallyInitialize = YES;
        }
    }
    
    if (reallyInitialize) {
        // We successfully set the CLS_INITIALIZING bit. Initialize the class.
        
        // Record that we're initializing this class so we can message it.
        _setThisThreadIsInitializingClass(cls);

        if (MultithreadedForkChild) {
            // LOL JK we don't really call +initialize methods after fork().
            performForkChildInitialize(cls, supercls);
            return;
        }
        
        // Send the +initialize message.
        // Note that +initialize is sent to the superclass (again) if 
        // this class doesn't implement +initialize. 2157218
        if (PrintInitializing) {
            _objc_inform("INITIALIZE: thread %p: calling +[%s initialize]",
                         pthread_self(), cls->nameForLogging());
        }

        // Exceptions: A +initialize call that throws an exception 
        // is deemed to be a complete and successful +initialize.
        //
        // Only __OBJC2__ adds these handlers. !__OBJC2__ has a
        // bootstrapping problem of this versus CF's call to
        // objc_exception_set_functions().
//#if __OBJC2__
        @try
//#endif
        {
            callInitialize(cls);

            if (PrintInitializing) {
                _objc_inform("INITIALIZE: thread %p: finished +[%s initialize]",
                             pthread_self(), cls->nameForLogging());
            }
        }
//#if __OBJC2__
        @catch (...) {
            if (PrintInitializing) {
                _objc_inform("INITIALIZE: thread %p: +[%s initialize] "
                             "threw an exception",
                             pthread_self(), cls->nameForLogging());
            }
            @throw;
        }
        @finally
//#endif
        {
            // Done initializing.
            lockAndFinishInitializing(cls, supercls);
        }
        return;
    }
    
    else if (cls->isInitializing()) {
        // We couldn't set INITIALIZING because INITIALIZING was already set.
        // If this thread set it earlier, continue normally.
        // If some other thread set it, block until initialize is done.
        // It's ok if INITIALIZING changes to INITIALIZED while we're here, 
        //   because we safely check for INITIALIZED inside the lock 
        //   before blocking.
        if (_thisThreadIsInitializingClass(cls)) {
            return;
        } else if (!MultithreadedForkChild) {
            waitForInitializeToComplete(cls);
            return;
        } else {
            // We're on the child side of fork(), facing a class that
            // was initializing by some other thread when fork() was called.
            _setThisThreadIsInitializingClass(cls);
            performForkChildInitialize(cls, supercls);
        }
    }
    
    else if (cls->isInitialized()) {
        // Set CLS_INITIALIZING failed because someone else already 
        //   initialized the class. Continue normally.
        // NOTE this check must come AFTER the ISINITIALIZING case.
        // Otherwise: Another thread is initializing this class. ISINITIALIZED 
        //   is false. Skip this clause. Then the other thread finishes 
        //   initialization and sets INITIALIZING=no and INITIALIZED=yes. 
        //   Skip the ISINITIALIZING clause. Die horribly.
        return;
    }
    
    else {
        // We shouldn't be here. 
        _objc_fatal("thread-safe class init in objc runtime is buggy!");
    }
}
```

```php

//重点是下面的触发机制：
void callInitialize(Class cls)
{
    ((void(*)(Class, SEL))objc_msgSend)(cls, SEL_initialize);
    asm("");
}

```
下面验证父类，子类，分类的initialize的调用顺序：

  1)只有父类实现了initialize方法：
```php
  2018-12-06 21:10:22.850174+0800 iOS底层原理总结[57496:3280540] 父类 initialize
  2018-12-06 21:10:22.850261+0800 iOS底层原理总结[57496:3280540] 父类 initialize
  *这种情况父类调用两次：因为initialize是走的objc_msgSend，根据消息转发机制，会有两次！自己仔细考虑
```
  2）父类和子类实现了initialize方法：
```php
   2018-12-06 21:16:14.588343+0800 iOS底层原理总结[58647:3289450] 父类 initialize
   2018-12-06 21:16:14.588407+0800 iOS底层原理总结[58647:3289450] 子类 initialize
   这种情况就属于正常的函数调用
```
  3）父类，子类，分类都实现了initialize方法：
```php
   2018-12-06 21:18:06.508961+0800 iOS底层原理总结[59050:3292825] 分类 initialize
   2018-12-06 21:18:06.512916+0800 iOS底层原理总结[59050:3292825] 子类 initialize
   父类的方法会被覆盖（准确来说是分类的优先执行）,且优于子类的执行
```


## 总结：

!‼️[load-VS-initialize](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/laod%2Binitlize.png)

文字总结：
Q1: Category中有load方法吗?load方法在什么时候调用？load方法能继承吗？<br>
A: Category中也有load方法，load方法在app启动程序加载类信息的时候调用，load方法可以继承，调用子类load方法会先调用父类方法。<br>

Q2:‼️load 和 initialize的区别，以及在Category重写时候的调用次序？<br>
A:区别在与调用时刻和调用方式：<br>
1.调用方式：load直接调用函数地址；initialize是通过objc_msgSend调用；<br>
2.调用时机：laod是runtime在加载类信息和分类信息的时候调用，（只会调用一次）；initialize是类第一次接收到消息的时候调用，每个类只会initialize一次，但是父类的initialize可能会调用多次；<br>
3.调用顺序：
   1)load:父类 -> 子类 -> 分类<br>
   2)initialize: 父类 -> 子类(如果有)<br>
   
   
   
   
*******
> [Category-本质](https://www.jianshu.com/p/fa66c8be42a2)<br>
> [Category的本质<二>load，initialize方法](http://www.cocoachina.com/ios/20180727/24346.html)<br>
> [Category的本质<一>](https://www.jianshu.com/p/da463f413de7)<br>
























