//
//  Student.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/2.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Student : NSObject
{
	@public
	int _no;
	int _age;
	NSString *address;
}
@property (nonatomic, strong) NSString *name;

- (void)studentName;
- (void)studentAddress;
@end

NS_ASSUME_NONNULL_END
