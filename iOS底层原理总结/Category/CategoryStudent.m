//
//  CategoryStudent.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/6.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "CategoryStudent.h"

@implementation CategoryStudent

+ (void)load
{
	NSLog(@"Class subClass load");
}

+ (void)initialize
{
	//	if (self == [<#ClassName#> class]) {
	//
	//	}
	NSLog(@"子类 initialize");
}

@end
