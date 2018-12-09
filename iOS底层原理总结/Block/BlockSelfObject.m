//
//  BlockSelfObject.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/8.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "BlockSelfObject.h"

@implementation BlockSelfObject

- (void)test
{
	void(^block)(void) = ^{
		NSLog(@"%@",self);
		NSLog(@"%@",self.name);
		NSLog(@"%@",_name);
	};
	block();
}

- (instancetype)initWithName:(NSString *)name
{
	self = [super init];
	if (self) {
		
	}
	return self;
}

+ (void)test2
{
	NSLog(@"this is class method");
}


@end
