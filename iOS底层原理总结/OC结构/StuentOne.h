//
//  StuentOne.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/2.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PersonOne.h"
NS_ASSUME_NONNULL_BEGIN

@interface StudentOne : PersonOne
{
@public
	int _no;
}
@property (nonatomic, assign) int score;
- (void)studentMethod;
+ (void)studentClassMethod;
@end
NS_ASSUME_NONNULL_END
