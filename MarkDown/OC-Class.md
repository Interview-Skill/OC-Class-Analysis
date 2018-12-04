# Class本质
无论类对象还是元类对象，类型都是Class类型；而其底层是objc_class结构体的指针，内存中就是结构体！
首先任何对象都是继承自NSObject;NSObject结构是：

```php
@interface NSObject <NSObject> {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
    Class isa  OBJC_ISA_AVAILABILITY;
#pragma clang diagnostic pop
}
```
Xcode对一个对象编译后为C++代码：
```php
struct Student_IMPL {
	struct NSObject_IMPL NSObject_IVARS;
	int _no;
	int _age;
	NSString *address;
	NSString * _Nonnull _name;
};
```

可以看到NSObject有个属性指向他们的类Class：下面来看下Class的结构：
```php
typedef struct objc_class *Class;
```
在底层Class是一个objc_class的struct；我们继续看objc_class的结构：
这是objc2之后的Class结构
```php
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;          // 
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
```
我们发现objc_class继承自objc_object;那么objc_object是什么？
```php
struct objc_object {
private:
    isa_t isa;

public:

    // ISA() assumes this is NOT a tagged pointer object
    Class ISA();

    // getIsa() allows this to be a tagged pointer object
    Class getIsa();
    ....
}
```
从这里我们发现在类对象中也有一个isa指针；

> 那么在类中的成员变量，实例方法，属性都放在哪里？
```php
struct class_rw_t { //这是一个readWrite
    // Be warned that Symbolication knows the layout of this structure.
    uint32_t flags; //
    uint32_t version;
    const class_ro_t *ro; //这里还有一个
    method_array_t methods; //存放方法列表
    property_array_t properties;  //属性列表
    protocol_array_t protocols; //协议列表

    Class firstSubclass;
    Class nextSiblingClass;

    char *demangledName;
    ....
}
```
下面注意看：const class_ro_t *ro;
```php
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;
#ifdef __LP64__
    uint32_t reserved;
#endif

    const uint8_t * ivarLayout;
    
    const char * name; //类名
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars; //成员变量

    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;

    method_list_t *baseMethods() const {
        return baseMethodList;
    }
};
```
一张图总结：
![struct-objcet](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/struct_object.png)

