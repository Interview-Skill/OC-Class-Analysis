//
//  PersonOne.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/2.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "PersonOne.h"
#import <objc/runtime.h>

@implementation PersonOne
- (void)personMethod {}
+ (void)personClassMethod {}

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self setup];
	}
	return self;
}

- (void)setup
{
	//person 是一个instance变量;进行alloc一个
//	PersonOne *person = [[PersonOne alloc] init];//person 是一个instance变量
//	//可以使用class方法或者runtime获取
//	Class class = [person class]; //class是类对象
//	Class class1 = object_getClass(person);//通过runtime获取类对象
//	//class或者runtime中传入的参数如果是类对象的话，就会获取元类对象
//	Class meta_class = [NSObject class];//获取元类对象
//	Class meta_class1 = object_getClass([PersonOne class]);//元类
//	if (class_isMetaClass(meta_class1)) {
//		NSLog(@"is meta-class");
//	}
	
	
}
@end
