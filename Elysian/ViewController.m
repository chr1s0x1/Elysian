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
    _section.layer.cornerRadius = 15;
    _section.layer.masksToBounds = YES;
    if( self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight ){
        _section.backgroundColor = [UIColor whiteColor];
    }
}
- (IBAction)JBGo:(id)sender {
    get_tfp0();
    
    LOG("[*] Starting Post Exploit");
    
    
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    if( self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight ){
        _section.backgroundColor = [UIColor whiteColor];
    }else {
        _section.backgroundColor = [UIColor colorWithRed:36.0/255.0 green:36.0/255.0 blue:36.0/255.0 alpha:1];
    }
}
@end
