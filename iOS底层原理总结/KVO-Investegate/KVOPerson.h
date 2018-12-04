//
//  KVOPerson.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/4.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KVOPerson : NSObject

@property (nonatomic, assign) double age;
@property (nonatomic, strong) NSString *address;

@end

NS_ASSUME_NONNULL_END
