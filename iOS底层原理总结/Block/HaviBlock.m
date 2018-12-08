//
//  HaviBlock.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/6.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "HaviBlock.h"

@implementation HaviBlock

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self createBlock];
		[self verifyBlock];
	}
	return self;
}

- (void)createBlock
{
	__block int age = 10;
	void(^block)(int, int) = ^(int a, int b) {
		NSLog(@"this is an block, a = %d, b = %d",a,b);
		NSLog(@"this is an block, age = %d",age );
	};
	block(3,5);
}

- (void)verifyBlock
{
	__block int age = 10;
	void(^block)(int, int) = ^(int a, int b) {
		NSLog(@"this is an block, a = %d, b = %d",a,b);
		NSLog(@"this is an block, age = %d",age );
	};
	struct __main_block_impl_0 *blockStruct = (__bridge struct __main_block_impl_0 *)block;
	block(3,5);
	
}

@end
