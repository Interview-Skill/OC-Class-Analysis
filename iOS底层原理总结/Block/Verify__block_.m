//
//  Verify__block_.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/9.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "Verify__block_.h"

@implementation Verify__block_

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self createBlock ];
	}
	return self;
}

- (void)createBlock
{
	__block int a = 10;
	
	void (^block)(void) = ^{
		a = 20;
		NSLog(@"print a:%d",a);
	};
	block();
}

@end
