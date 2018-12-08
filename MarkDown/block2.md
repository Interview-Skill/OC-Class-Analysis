## block对对象变量的捕获：

block在使用过程中一般都是对对象的捕获，那么对对象的捕获是不是和基础类型一样？当block访问的是对象类型的话，对象在什么时候销毁？

### 查看block捕获对象类型的C++源码
```php
- (void)blockCaptureObject
{
	Block block;
	{
		CategoryPerson *p = [CategoryPerson new];
		p.age = 10;
		block = ^ {
			NSLog(@"person age: %d",p.age);
		};
		
	}
}
```

