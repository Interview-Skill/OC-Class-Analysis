//
//  main.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/1.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "Student.h"
#import <objc/runtime.h>

int main(int argc, char * argv[]) {
	@autoreleasepool {
		NSLog(@"begin");
		int re = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
		NSLog(@"end");
		return re;
	}
}
