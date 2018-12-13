//
//  Person.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/11.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject
{
	struct {
		char handsome : 1;
		char rich : 1;
		char tall : 1;
	} _tallRichHandsome;
}

/*如果我们直接使用属性的话，会分配三个byte的内存空间，实际上我们只需要一个byte的内存空间就够了，一个byte内存空间有8个bits
 */

@property (nonatomic, assign, getter=isTall) BOOL tall;
@property (nonatomic, assign, getter=isRich) BOOL rich;
@property (nonatomic, assign, getter=isHansome) BOOL handsome;

@end

NS_ASSUME_NONNULL_END
