# KVO底层探究
### How to Use KVO?
```php
KVOPerson *kvoPerson1 = [[KVOPerson alloc] init];
KVOPerson *kvoPerson2 = [[KVOPerson alloc] init];
kvoPerson1.age = 1;
kvoPerson2.age = 2;

[kvoPerson1 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
kvoPerson1.age = 10;
kvoPerson2.age = 12;
//现在你需要实现delegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	NSLog(@"receive %@", change);
}
```
> 思考问题：<br>
iOS用什么方式实现对一个对象的KVO？（KVO的本质是什么？）<br>
如何手动触发KVO?<br>

### 探究KVO底层实现原理
> 从代码中可以看到，只要属性值发生变化，就会触发我们的监听回调！<br>
即使我们重写age属性值，监听回调也可以正常运行。

### KVO底层实现分析

通过对上面的代码，我们分析发现kvoPerson2在添加kvo之后发生了变化，我们通过断点来查看这两个对象的isa即类对象，根据一个类的类对象唯一性，kvoPerson1 和kvoPerson2的类对象
应该一致：
但是😲😲😲😲：
![kvo-isa](https://github.com/Interview-Skill/OC-Class-Analysis/blob/master/Image/kvo-isa.png)
从上图的打印我们可以发现添加KVO之后，kvoPerson1的isa指向了一个新的类对象NSKVONotifying_KVOPerson
下面分析setAge方法在添加kvo和没有添加时的左右：

