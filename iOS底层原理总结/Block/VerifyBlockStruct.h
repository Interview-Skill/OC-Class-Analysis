//
//  VerifyBlockStruct.h
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/7.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

struct __main_block_desc_0 {
	size_t reserved;
	size_t Block_size;
};

struct __block_impl {
	void *isa;
	int Flags;
	int Reserved;
	void *FuncPtr;
};

struct __main_block_impl_0 {
	struct __block_impl impl;
	struct __main_block_desc_0* Desc;
	int age;
};

@interface VerifyBlockStruct : NSObject

@end

NS_ASSUME_NONNULL_END
