//
//  ViewController.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/1.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "ViewController.h"
#import "PersonOne.h"
#import "KVOPerson.h"
#import <objc/runtime.h>
#import "Student.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	PersonOne *person = [[PersonOne alloc] init];//person 是一个instance变量
	//可以使用class方法或者runtime获取
	Class class = [person class]; //class是类对象
	Class class1 = object_getClass(person);//通过runtime获取类对象
	//class或者runtime中传入的参数如果是类对象的话，就会获取元类对象
	Class meta_class = [NSObject class];//获取元类对象
	Class meta_class1 = object_getClass([PersonOne class]);//元类
	if (class_isMetaClass(meta_class1)) {
		NSLog(@"is meta-class");
	}
	
	//
	NSObject *object1 = [[NSObject alloc] init];
	NSObject *object2 = [[NSObject alloc] init];
	NSLog(@"%p %p", object1, object2);
	Class objectClass1 = [object1 class];
	Class objectClass2 = [object2 class];
	Class objectClass3 = [NSObject class];
	// runtime
	Class objectClass4 = object_getClass(object1);
	Class objectClass5 = object_getClass(object2);
	NSLog(@"%p %p %p %p %p", objectClass1, objectClass2, objectClass3, objectClass4, objectClass5);
	
	// runtime
	Class metaObjectClass1 = object_getClass([NSObject class]);
	Class metaObjectClass2 = [NSObject class];
	NSLog(@"%p %p", metaObjectClass1, metaObjectClass2);
	
	KVOPerson *kvoPerson1 = [[KVOPerson alloc] init];
	KVOPerson *kvoPerson2 = [[KVOPerson alloc] init];
	KVOPerson *kvoPerson3 = [KVOPerson new];
	kvoPerson1.age = 1;
	kvoPerson2.age = 2;
	
	// 通过methodForSelector找到方法实现的地址
//	NSLog(@"添加KVO监听之前 - p1 = %p, p2 = %p", [kvoPerson1 methodForSelector: @selector(setAge:)],[kvoPerson2 methodForSelector: @selector(setAge:)]);
	
	NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
	[kvoPerson1 addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
	kvoPerson1.age = 100;
//	NSLog(@"添加KVO监听之后 - p1 = %p, p2 = %p", [kvoPerson1 methodForSelector: @selector(setAge:)],[kvoPerson2 methodForSelector: @selector(setAge:)]);
//
//	[self printClassMethod:object_getClass(kvoPerson1)];
//	[self printClassMethod:object_getClass(kvoPerson2)];
	Student *stu = [[Student alloc] init];
	stu -> _no = 4;
	stu -> _age = 5;
	stu.name = @"li";
	
	Class studentClass = [stu class];
	Class studentMetaClass = [Student class];
	NSLog(@"%@",stu);
	NSLog(@"%zd,%zd", class_getInstanceSize([NSObject class]) ,class_getInstanceSize([Student class]));
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	NSLog(@"receive %@", change);
}

- (void)printClassMethod:(Class)cls
{
	unsigned int count;
	Method *methods = class_copyMethodList(cls, &count);
	NSMutableString *methodNames = [NSMutableString string];
	[methodNames appendFormat:@"%@ - ", cls];
	for (int i = 0; i< count; i++) {
		Method method = methods[i];
		NSString *methodName = NSStringFromSelector(method_getName(method));
		[methodNames appendString: methodName];
		[methodNames appendString:@"--- "];
	}
	NSLog(@"%@",methodNames);
	free(methods);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	NSLog(@"touch screen");
	[self performSelector:@selector(test) withObject:nil];
}

- (void)test
{
	NSLog(@"perform selector");
}
@end
