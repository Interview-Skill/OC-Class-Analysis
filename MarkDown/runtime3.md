# 1.方法调用本质

首先我们通过一段代码来看看方法调用转为C++是什么样子：
```php
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m
```

# 2.消息发送

## 1）方法查找

### _class_lookupMethodAndLoadCache3函数

### lookUpImpOrForward函数

### getMethodNoSuper_nolock函数

## 2）动态解析阶段

### 代码结构

### 动态解析实例方法

### 动态解析类方法

# 3.消息转发

## 1）NSInvocation

# 4.类方法的消息转发
