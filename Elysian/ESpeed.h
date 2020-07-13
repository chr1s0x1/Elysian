//
//  ESpeed.h
//  Elysian
//
//  Created by chris  on 6/23/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef ESpeed_h
#define ESpeed_h


/*
 function: ESpeed - (E)xploit Speed
 
 Use: Takes advantage of HSP4 to jailbreak the iOS device.
 
 What ESpeed does:
 
 - grabs tfp0
 - unsandboxes our process
 - initiates jelbrekLibE
 - Escalates our task
 */

mach_port_t ESpeed(void);
#endif /* ESpeed_h */
