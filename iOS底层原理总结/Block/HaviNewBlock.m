//
//  HaviBlock.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/6.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "HaviNewBlock.h"
#import "Verify__block_.h"
typedef void (^Block) (void);
@implementation HaviNewBlock

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self createBlock];
		[self verifyBlock];
		[self blockType];
		
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
	
	void (^block1)(void) = ^{
		NSLog(@"Hello");
	};
	
	NSLog(@"block -------%@", [block class]);
	NSLog(@"block -------%@", [[block1 class] superclass]);
	NSLog(@"block -------%@", [[[block1 class] superclass] superclass]);
	NSLog(@"block -------%@", [[[[block1 class] superclass] superclass] superclass]);
	
	Verify__block_ *_b = [[Verify__block_ alloc] init];
	
}

- (void)verifyBlock
{
	int age = 10;
	static int ageB = 11;
	void(^block)(int, int) = ^(int a, int b) {
		NSLog(@"this is an block, a = %d, b = %d",a,b);
		NSLog(@"this is an block, age = %d",age );
		NSLog(@"this is an block, ageB = %d",ageB);
	};
	struct __main_block_impl_0 *blockStruct = (__bridge struct __main_block_impl_0 *)block;
	block(3,5);
	
}

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

- (void)blockType
{
	//1.内部没有调用外部任何变量的block
	void (^block1)(void) = ^{
		NSLog(@"hello");
	};
	
	//2.调用外部变量的block
	int a = 10;
	void (^block2)(void) = ^{
		NSLog(@"hello---%d",a);
	};
	
	//3.直接调用block
	
	NSLog(@"block-type:%@----%@----%@",[block1 class],[block2 class],[^{NSLog(@"%d",a);} class]);
}

@end
