## OC代码转化为C++:
- clang -rewrite-objc main.m -o main.cpp // 这种方式没有指定架构例如arm64架构 其中cpp代表（c plus plus）生成 main.cpp
- 如果你直接使用会报错;请使用：clang -x objective-c -rewrite-objc -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk xxxxx.m
  - 将此命令设置为zsh常用命令：[详情](https://www.jianshu.com/p/43a09727eb2c)
