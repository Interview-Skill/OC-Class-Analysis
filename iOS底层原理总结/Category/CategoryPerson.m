//
//  CategoryPerson.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/5.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "CategoryPerson.h"

@implementation CategoryPerson
- (void)run
{
	NSLog(@"person run");
}

+ (void)load
{
	NSLog(@"Class Load");
}

+ (void)initialize
{
//	if (self == [<#ClassName#> class]) {
//
//	}
	NSLog(@"父类 initialize");
}
@end
