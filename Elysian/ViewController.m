//
//  ViewController.m
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import "ViewController.h"
#import "exploit.h"
#import "jailbreak.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *Label;

@property (weak, nonatomic) IBOutlet UIButton *JBButton;
@property (strong, nonatomic) IBOutlet UIView *section;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
- (IBAction)JBGo:(id)sender {
    get_tfp0();
    
    LOG("[*] Starting Post Exploit");
    
    
}

@end
