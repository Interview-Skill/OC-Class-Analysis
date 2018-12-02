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
		Student *stu = [[Student alloc] init];
		stu -> _no = 4;
		stu -> _age = 5;
		
		NSLog(@"%@",stu);
		NSLog(@"%zd,%zd", class_getInstanceSize([NSObject class]) ,class_getInstanceSize([Student class]));
	    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
	}
}
