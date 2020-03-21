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

#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *Label;

@property (weak, nonatomic) IBOutlet UIButton *JBButton;
@property (strong, nonatomic) IBOutlet UIView *section;

@end


@implementation ViewController




- (void)viewDidLoad {
    
    // Version check
    if(SYSTEM_VERSION_GREATER_THAN(@"13.3") || SYSTEM_VERSION_LESS_THAN(@"13.0")){
    printf("[-] Unsupported Firmware!\n");
        [_JBButton setTitle:@"Unsupported" forState:UIControlStateNormal];
        _JBButton.enabled = NO;
    }
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}




- (IBAction)JBGo:(id)sender {
    _JBButton.enabled = NO;
    LOG("[*] Starting Exploit\n");
    __block mach_port_t tfpzero = MACH_PORT_NULL;
    tfpzero = get_tfp0();
    if(!MACH_PORT_VALID(tfpzero)){
        LOG("[-] Exploit Failed \n");
        LOG("[i] Please reboot and try again \n");
        [sender setTitle:@"Exploit Failed" forState:UIControlStateNormal];
        return;
    }
    LOGM("[i] tfp0 : 0x%x \n", tfpzero);
    
/* Start of Elysian Jailbreak *****************************************************/
    
    LOG("[*] Starting Jailbreak Process \n");
    
    [_JBButton setTitle:@"Jailbreaking.." forState:UIControlStateNormal];
    
    LOGM("[i] KernelBase: 0x%llx\n", KernelBase);
    // initalize jelbrekLibE
    init_with_kbase(tfpzero, KernelBase, NULL);
    LOG("[+] Geting Root Permissions \n"); // give ourselves root perms
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
