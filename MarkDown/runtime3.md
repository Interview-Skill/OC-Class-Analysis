# 1.方法调用本质

首先我们通过一段代码来看看方法调用转为C++是什么样子：

```php
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m
```

```php
[person test];
//  --------- c++底层代码
((void (*)(id, SEL))(void *)objc_msgSend)((id)person, sel_registerName("test"));
```

通过上面的源码可以看出C++调用底层代码中的方法的时候，都是转化为`objc_msgSend`函数，在OC中方法调用也叫消息机制，表示给方法调用者发送消息。

在方法调用的过程中可以分为三个阶段：

1. **消息发送阶段：** 负责从类及父类的缓存列表及方法列表中找到方法。

2. **动态解析阶段**：如果消息发送阶段没有找到方法，则会进入动态解析阶段，负责动态的添加方法实现。

3. **消息转发阶段**：如果也没有实现动态解析方法，则会进行消息转发阶段，将消息转发给可以处理消息的接收者来处理。

如果消息转发也没有实现，就会报方法找不到的错误，无法识别消息：`unrecognzied selector sent to instance`

# 2.消息发送

在runtime源码中搜索`_objc_msgsent`查看内部实现:

```php
/********************************************************************
 *
 * id objc_msgSend(id self, SEL _cmd, ...);
 * IMP objc_msgLookup(id self, SEL _cmd, ...);
 * 
 * objc_msgLookup ABI:
 * IMP returned in x17
 * x16 reserved for our use but not used
 *
 ********************************************************************/

#if SUPPORT_TAGGED_POINTERS
	.data
	.align 3
	.globl _objc_debug_taggedpointer_classes
_objc_debug_taggedpointer_classes:
	.fill 16, 8, 0
	.globl _objc_debug_taggedpointer_ext_classes
_objc_debug_taggedpointer_ext_classes:
	.fill 256, 8, 0
#endif

	ENTRY _objc_msgSend
	UNWIND _objc_msgSend, NoFrame

	cmp	p0, #0			// nil check and tagged pointer check
#if SUPPORT_TAGGED_POINTERS
	b.le	LNilOrTagged		//  (MSB tagged pointer looks negative)
#else
	b.eq	LReturnZero
#endif
	ldr	p13, [x0]		// p13 = isa
	GetClassFromIsa_p16 p13		// p16 = class
LGetIsaDone:
	CacheLookup NORMAL		// calls imp or objc_msgSend_uncached

#if SUPPORT_TAGGED_POINTERS
LNilOrTagged:
	b.eq	LReturnZero		// nil check

	// tagged
	adrp	x10, _objc_debug_taggedpointer_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_classes@PAGEOFF
	ubfx	x11, x0, #60, #4
	ldr	x16, [x10, x11, LSL #3]
	adrp	x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGE
	add	x10, x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGEOFF
	cmp	x10, x16
	b.ne	LGetIsaDone

	// ext tagged
	adrp	x10, _objc_debug_taggedpointer_ext_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_ext_classes@PAGEOFF
	ubfx	x11, x0, #52, #8
	ldr	x16, [x10, x11, LSL #3]
	b	LGetIsaDone
// SUPPORT_TAGGED_POINTERS
#endif

LReturnZero:
	// x0 is already zero
	mov	x1, #0
	movi	d0, #0
	movi	d1, #0
	movi	d2, #0
	movi	d3, #0
	ret

	END_ENTRY _objc_msgSend

```

上面的代码会首先判断消息接受者`receiver`的值。如果传入的消息接收者为`nil`则会执行`LNilOrTagged`,`LNilOrTagged`内部则会执行`LReturnZero`，而在`LRetureZero`内部则直接return0。

如果传入的消息接受者不为nil,则执行`CacheLookup`,内部对方法荤菜列表进行查找，如果找到则执行`CacheHit`,进而调用方法，否则执行`CheckMiss`,`CheckMiss`内部调用了`__objc_msgsend_uncached`.

`__objc_msgsend_uncached`内部会执行`MethodTableLookup`,也就是方法列表进行查找，`MethodTableLookup`内部的核心代码`__class_lookupMethodAndLoadCache3`也就是c语言`__class_lookupMethodAndLoadCache3`。

⚠️**c语言__class_lookupMethodAndLoadCache3 函数内部则是对方法查找的核心代码**

下面是汇编语言中**___objc_msgSend** 的运行流程：

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime3-1.png)

## 1）方法查找

### _class_lookupMethodAndLoadCache3函数

```php
/***********************************************************************
* _class_lookupMethodAndLoadCache.
* Method lookup for dispatchers ONLY. OTHER CODE SHOULD USE lookUpImp().
* This lookup avoids optimistic cache scan because the dispatcher 
* already tried that.
**********************************************************************/
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{
    return lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}
```

### lookUpImpOrForward函数

```php
/***********************************************************************
* lookUpImpOrForward.
* The standard IMP lookup. 
* initialize==NO tries to avoid +initialize (but sometimes fails)
* cache==NO skips optimistic unlocked lookup (but uses cache elsewhere)
* Most callers should use initialize==YES and cache==YES.
* inst is an instance of cls or a subclass thereof, or nil if none is known. 
*   If cls is an un-initialized metaclass then a non-nil inst is faster.
* May return _objc_msgForward_impcache. IMPs destined for external use 
*   must be converted to _objc_msgForward or _objc_msgForward_stret.
*   If you don't want forwarding at all, use lookUpImpOrNil() instead.
**********************************************************************/
IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;

    runtimeLock.assertUnlocked();

    // Optimistic cache lookup
    if (cache) {
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }

    // runtimeLock is held during isRealized and isInitialized checking
    // to prevent races against concurrent realization.

    // runtimeLock is held during method search to make
    // method-lookup + cache-fill atomic with respect to method addition.
    // Otherwise, a category could be added but ignored indefinitely because
    // the cache was re-filled with the old value after the cache flush on
    // behalf of the category.

    runtimeLock.lock();
    checkIsKnownClass(cls);

    if (!cls->isRealized()) {
        realizeClass(cls);
    }

    if (initialize  &&  !cls->isInitialized()) {
        runtimeLock.unlock();
        _class_initialize (_class_getNonMetaClass(cls, inst));
        runtimeLock.lock();
        // If sel == initialize, _class_initialize will send +initialize and 
        // then the messenger will send +initialize again after this 
        // procedure finishes. Of course, if this is not being called 
        // from the messenger then it won't happen. 2778172
    }

    
 retry:    
    runtimeLock.assertLocked();

    // Try this class's cache.

    imp = cache_getImp(cls, sel);
    if (imp) goto done;

    // Try this class's method lists.
    {
        Method meth = getMethodNoSuper_nolock(cls, sel);
        if (meth) {
            log_and_fill_cache(cls, meth->imp, sel, inst, cls);
            imp = meth->imp;
            goto done;
        }
    }

    // Try superclass caches and method lists.
    {
        unsigned attempts = unreasonableClassCount();
        for (Class curClass = cls->superclass;
             curClass != nil;
             curClass = curClass->superclass)
        {
            // Halt if there is a cycle in the superclass chain.
            if (--attempts == 0) {
                _objc_fatal("Memory corruption in class list.");
            }
            
            // Superclass cache.
            imp = cache_getImp(curClass, sel);
            if (imp) {
                if (imp != (IMP)_objc_msgForward_impcache) {
                    // Found the method in a superclass. Cache it in this class.
                    log_and_fill_cache(cls, imp, sel, inst, curClass);
                    goto done;
                }
                else {
                    // Found a forward:: entry in a superclass.
                    // Stop searching, but don't cache yet; call method 
                    // resolver for this class first.
                    break;
                }
            }
            
            // Superclass method list.
            Method meth = getMethodNoSuper_nolock(curClass, sel);
            if (meth) {
                log_and_fill_cache(cls, meth->imp, sel, inst, curClass);
                imp = meth->imp;
                goto done;
            }
        }
    }

    // No implementation found. Try method resolver once.

    if (resolver  &&  !triedResolver) {
        runtimeLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        runtimeLock.lock();
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
        triedResolver = YES;
        goto retry;
    }

    // No implementation found, and method resolver didn't help. 
    // Use forwarding.

    imp = (IMP)_objc_msgForward_impcache;
    cache_fill(cls, sel, imp, inst);

 done:
    runtimeLock.unlock();

    return imp;
}
```

### getMethodNoSuper_nolock函数

方法列表中查找方法：

```php
static method_t *
getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();
    assert(cls->isRealized());
    // cls->data()得到的是class_rw_t
    // class_rw_t->method 得到的是methods二维数组
    // fixme nil cls? 
    // fixme nil sel?
    for (auto mlists = cls->data()->methods.beginLists(), 
              end = cls->data()->methods.endLists(); 
         mlists != end;
         ++mlists)
    {
        method_t *m = search_method_list(*mlists, sel);
        if (m) return m;
    }

    return nil;
}
```

上面的代码中`getMethodNoSuper_nolock`函数中通过遍历方法列表拿到`method_list_t`最终通过`search_method_list`查找方法。

### **`search_method_list`函数**

```php
static method_t *search_method_list(const method_list_t *mlist, SEL sel)
{
    int methodListIsFixedUp = mlist->isFixedUp();
    int methodListHasExpectedSize = mlist->entsize() == sizeof(method_t);
    // 如果方法列表是有序的，则使用二分法查找方法，节省时间
    if (__builtin_expect(methodListIsFixedUp && methodListHasExpectedSize, 1)) {
        return findMethodInSortedMethodList(sel, mlist);
    } else {
        // 否则则遍历列表查找
        for (auto& meth : *mlist) {
            if (meth.name == sel) return &meth;
        }
    }
    return nil;
}
```

### **`findMethodInSortedMethodList`函数内二分查找实现原理**

```php
static method_t *findMethodInSortedMethodList(SEL key, const method_list_t *list)
{
    assert(list);

    const method_t * const first = &list->first;
    const method_t *base = first;
    const method_t *probe;
    uintptr_t keyValue = (uintptr_t)key;
    uint32_t count;
    // >>1 表示将变量n的各个二进制位顺序右移1位，最高位补二进制0。
    // count >>= 1 如果count为偶数则值变为(count / 2)。如果count为奇数则值变为(count-1) / 2 
    for (count = list->count; count != 0; count >>= 1) {
        // probe 指向数组中间的值
        probe = base + (count >> 1);
        // 取出中间method_t的name，也就是SEL
        uintptr_t probeValue = (uintptr_t)probe->name;
        if (keyValue == probeValue) {
            // 取出 probe
            while (probe > first && keyValue == (uintptr_t)probe[-1].name) {
                probe--;
            }
           // 返回方法
            return (method_t *)probe;
        }
        // 如果keyValue > probeValue 则折半向后查询
        if (keyValue > probeValue) {
            base = probe + 1;
            count--;
        }
    }
    
    return nil;
}
```

上面的函数就是`_class_lookupMethodAndLoadCache3`的整个发送流程：

![image](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/runtime3-2.png)

如果没有找到方法，下面就会进入动态解析阶段。

## 2）动态解析阶段

当本类包括父类`cache`以及`class_rw_t`中都找不到方法时，就会进入动态解析阶段。我们来看动态解析的源代码。

```php

    // No implementation found. Try method resolver once.

    if (resolver  &&  !triedResolver) {
        runtimeLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        runtimeLock.lock();
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
        triedResolver = YES;
        goto retry;
    }
```

#### `**_class_resolveMethod**`函数内部，根据类对象或元类对象做不同的操作

```php

/***********************************************************************
* _class_resolveMethod
* Call +resolveClassMethod or +resolveInstanceMethod.
* Returns nothing; any result would be potentially out-of-date already.
* Does not check if the method already exists.
**********************************************************************/
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
    if (! cls->isMetaClass()) {
        // try [cls resolveInstanceMethod:sel]
        _class_resolveInstanceMethod(cls, sel, inst);
    } 
    else {
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
        _class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                            NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}
```

上面的代码可以知道，动态解析之后，会把`triedResolver = YES`,那么下次的时候就不会再进行动态解析了，之后会进行`retry`把方法查找流程重走一遍。也就是无论动态解析是否成功，`retry`之后都不会再进行动态解析了。



### 3) 如何动态解析方法

1. **动态解析对象方法：**使用`+(BOOL)resolveInstanceMethod:(SEL)sel`

2. **动态解析类方法：**使用`+(BOOL)resolveClassMethod:(SEL)sel`

#### 1. 动态解析实例方法

下面是一个动态解析的代码示例：

```php
@implementation Person
- (void) other {
    NSLog(@"%s", __func__);
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    // 动态的添加方法实现
    if (sel == @selector(test)) {
        // 获取其他方法 指向method_t的指针
        Method otherMethod = class_getInstanceMethod(self, @selector(other));
        
        // 动态添加test方法的实现
        class_addMethod(self, sel, method_getImplementation(otherMethod), method_getTypeEncoding(otherMethod));
        
        // 返回YES表示有动态添加方法
        return YES;
    }
    
    NSLog(@"%s", __func__);
    return [super resolveInstanceMethod:sel];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *person = [[Person alloc] init];
        [person test];
    }
    return 0;
}
// 打印结果
// -[Person other]
```

上面的代码中，`person`在调用`test`方法之后动态解析成功调用了`other`方法。

通过上面对消息发送的分析我们知道，当本类和父类`cache`和`class_rw_t`中都找不到方法时，就会进行动态解析的方法，也就是说会自动调用类的`resolveInstanceMethod:`方法进行动态查找。因此我们可以在`resolveInstanceMethod:`方法内部使用`class_addMethod`动态的添加方法实现。

⚠️这里需要注意`class_addMethod`用来向具有给定名称和实现的类添加新方法，`class_addMethod`将添加一个方法实现的覆盖，但是不会替换已有的实现。也就是说如果上述代码中已经实现了`-(void)test`方法，则不会再动态添加方法，这点在上述源码中也可以体现，因为一旦找到方法实现就直接return imp并调用方法了，不会再执行动态解析方法了。



`class_addMethod函数`

首先来看下`class_addMethod`参数意义：

```php
/** 
     第一个参数： cls:给哪个类添加方法
     第二个参数： SEL name:添加方法的名称
     第三个参数： IMP imp: 方法的实现，函数入口，函数名可与方法名不同（建议与方法名相同）
     第四个参数： types :方法类型，需要用特定符号，参考API
     */
class_addMethod(__unsafe_unretained Class cls, SEL name, IMP imp, const char *types)

```

需要注意的是在上面的代码中`class_getInstanceMethod`获取`Method`的方法：

```php
// 获取其他方法 指向method_t的指针
Method otherMethod = class_getInstanceMethod(self, @selector(other));
```

其实Method是`objc_method`类型的结构体，可以理解为其内部结构同`method_t`相同，上文中的`method_t`是代表方法的结构体，其内部包含`SEL,type,IMP`，我们可以通过自定义`method__t`结构体，将objc_method强制转化为`method_t`来查看方法是否可以动态添加成功。

```php
struct method_t {
    SEL sel;
    char *types;
    IMP imp;
};

- (void) other {
    NSLog(@"%s", __func__);
}

+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    // 动态的添加方法实现
    if (sel == @selector(test)) {
        // Method强转为method_t
        struct method_t *method = (struct method_t *)class_getInstanceMethod(self, @selector(other));
        
        NSLog(@"%s,%p,%s",method->sel,method->imp,method->types);
        
        // 动态添加test方法的实现
        class_addMethod(self, sel, method->imp, method->types);
        
        // 返回YES表示有动态添加方法
        return YES;
    }
    
    NSLog(@"%s", __func__);
    return [super resolveInstanceMethod:sel];
}


动态解析方法[3246:1433553] other,0x100000d00,v16@0:8
动态解析方法[3246:1433553] -[Person other]
```

可以看出确实可以打印出相关信息，那么我们就可以理解为`objc_method`内部结构同`method_t`结构体相同，可以代表类定义中的方法。

另外上述代码中我们通过`method_getImplementation`函数和`method_getTypeEncoding`函数获取方法的`imp`和`type`。当然我们也可以通过自己写的方式来调用，这里以动态添加有参数的方法为例。

```php
+(BOOL)resolveInstanceMethod:(SEL)sel
{
    if (sel == @selector(eat:)) {
        class_addMethod(self, sel, (IMP)cook, "v@:@");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}
void cook(id self ,SEL _cmd,id Num)
{
    // 实现内容
    NSLog(@"%@的%@方法动态实现了,参数为%@",self,NSStringFromSelector(_cmd),Num);
}
```

上述代码中当调用`eat:`方法时，动态添加了`cook`函数作为其实现并添加id类型的参数。

#### 2. 动态解析类方法



# 3.消息转发

## 1）NSInvocation

# 4.类方法的消息转发
