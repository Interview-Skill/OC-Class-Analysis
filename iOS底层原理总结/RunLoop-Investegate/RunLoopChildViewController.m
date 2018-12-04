//
//  RunLoopChildViewController.m
//  iOS底层原理总结
//
//  Created by Li, Havi X. -ND on 2018/12/4.
//  Copyright © 2018 Li, Havi X. -ND. All rights reserved.
//

#import "RunLoopChildViewController.h"

@interface RunLoopChildViewController ()

@end

@implementation RunLoopChildViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	NSLog(@"child begin");
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
