//
//  CategoryPerson+Test.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/5.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "CategoryPerson.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PersonTest <NSObject>

- (void)personProtocol;

@end

@interface CategoryPerson (Test) <NSCopying>

- (void)test;
+ (void)abc;
@property (nonatomic, assign) int age;

- (void)setAge:(int)age;
- (int)age;

@end

NS_ASSUME_NONNULL_END
