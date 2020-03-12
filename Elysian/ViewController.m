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
#import "jelbrekLib.h"

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
    _JBButton.enabled = NO;
    [sender setTitle: @"Exploiting Kernel.." forState:UIControlStateNormal];
    
    LOG("[*] Starting Exploit");
    __block mach_port_t tfpzero = MACH_PORT_NULL;
    tfpzero = get_tfp0();
    if(!MACH_PORT_VALID(tfpzero)){
        LOG("[-] Exploit Failed \n");
        LOG("[i] Please reboot and try again \n");
        [sender setTitle:@"Exploit Failed" forState:UIControlStateNormal];
        return;
       
    }
    
    LOG("[*] Starting Jailbreak Process \n");
    
/* Start of Elysian Jailbreak ***************************************************************/
    LOG("[+] Unsandboxing \n");
    // Set sandbox pointer to 0;
    [sender setTitle:@"Unsandboxing.." forState:UIControlStateNormal];
    unsandbox(getpid());
    // Do we have root?
    FILE *f = fopen("/var/mobile/.elytest", "w");
    if(!f){
    LOG("[-] Failed to Unsanbox");
     [sender setTitle:@"Unsanbox failed" forState:UIControlStateNormal];
     return;
    }
    LOG("[*] Escaped Sandbox");
    sleep(1);
    
    // Remount..
    LOG("[+] Remounting");
    [sender setTitle:@"Remounting.." forState:UIControlStateNormal];
}

@end
