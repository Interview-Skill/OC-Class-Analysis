//
//  Person.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/11.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "Person.h"

@interface Person ()
{
//	char _tallRichHandsome;
}
@end

#define TallMask 1<<2 //0b0000 0100 = 4
#define RichMask 1<<1 //0b0000 0010 = 2
#define HandsomeMask 1<<0 //0


@implementation Person

- (instancetype)init
{
	self = [super init];
	if (self) {
		NSLog(@"");
		[self printClassSize];
	}
	return self;
}

- (BOOL)isTall
{
	return _tallRichHandsome.tall;
//	return !!(_tallRichHandsome & TallMask);
}

- (BOOL)isRich
{
//	return  !!(_tallRichHandsome & RichMask);
	return _tallRichHandsome.rich;
}

- (BOOL)isHansome
{
	return _tallRichHandsome.handsome;
//	return !!(_tallRichHandsome & HandsomeMask);
}

- (void)setTall:(BOOL)tall
{
	_tallRichHandsome.tall = tall;
//	if (tall) {//如果设置值为1，只需要进行按位取或。
//		_tallRichHandsome |= TallMask;
//	} else {
//		//如果需要将值设置为0，需要先取反，然后进行按位取与
//		_tallRichHandsome &= ~TallMask;
//	}
}

- (void)setRich:(BOOL)rich
{
	_tallRichHandsome.rich = rich;
//	if (rich) {
//		_tallRichHandsome |= RichMask;
//	} else {
//		_tallRichHandsome &= ~RichMask;
//	}
}

- (void)setHandsome:(BOOL)handsome
{
	_tallRichHandsome.handsome = handsome;
//	if (handsome) {
//		_tallRichHandsome |= HandsomeMask;
//	} else {
//		_tallRichHandsome &= ~HandsomeMask;
//	}
}

- (void)printClassSize
{
	NSLog(@"Person size:%ld", class_getInstanceSize([Person class]));
}

@end
