//
//  ViewController.m
//  Elysian
//
//  Created by chr1spwn3d on 3/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import "ViewController.h"
#import "exploit.h"
#import "utils.h"
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
    LOG("[*] Starting Exploit\n");
    __block mach_port_t tfpzero = MACH_PORT_NULL;
    tfpzero = get_tfp0();
    if(!MACH_PORT_VALID(tfpzero)){
        LOG("[-] Exploit Failed \n");
        LOG("[i] Please reboot and try again \n");
        [sender setTitle:@"Exploit Failed" forState:UIControlStateNormal];
        return;
       
    }
    
    LOG("[*] Starting Jailbreak Process \n");
    
/* Start of Elysian Jailbreak *****************************************************/
    LOG("[+] Geting Root Permissions \n");
    kern_return_t ret = rootify(getpid());
    if(ret != KERN_SUCCESS) {
        LOG("[-] Getting Root Perms Failed");
        [sender setTitle:@"Set Root Perms Failed" forState:UIControlStateNormal];
        return;
    }
    LOG("[+] Unsandboxing \n");
     // Set sandbox pointer to 0;
    unsandbox(getpid());
    // Do we have root?
    createFILE("/var/mobile/.elytest", nil);
    FILE *f = fopen("/var/mobile/.elytest", "w");
    if(!f){
    LOG("[-] Failed to Unsanbox \n");
     [sender setTitle:@"Unsanbox failed" forState:UIControlStateNormal];
     return;
    }
    LOG("[*] Escaped Sandbox \n");
    // Give us time to cool down
    sleep(1);
    
    // Remount..
    LOG("[+] Remounting \n");
    [sender setTitle:@"Remounting.." forState:UIControlStateNormal];
}

@end
