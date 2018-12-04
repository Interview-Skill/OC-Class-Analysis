//
//  KVOPerson.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/4.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "KVOPerson.h"

@implementation KVOPerson

- (void)setAge:(double)age
{
	_age = age;
}

- (void)willChangeValueForKey:(NSString *)key
{
	NSLog(@"willChangeValueForKey: --begin");
	[super willChangeValueForKey:key];
	NSLog(@"willChangeValueForKey: -- end");
}

- (void)didChangeValueForKey:(NSString *)key
{
	NSLog(@"didChangeValueForKey: --begin");
	[super didChangeValueForKey:key];
	NSLog(@"didChangeValueForKey: -- end");
}

@end
