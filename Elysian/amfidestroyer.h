//
//  amfidestroyer.h
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef amfidestroyer_h
#define amfidestroyer_h

#pragma pack(4)
typedef struct {
    mach_msg_header_t Head;
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t thread;
    mach_msg_port_descriptor_t task;
    NDR_record_t NDR;
} exception_raise_request; // the bits we need at least

typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
} exception_raise_reply;
#pragma pack()

/*
 function: hijacksysdiagnose
 
 Use:
 borrows/steals the sysdiagnose creds to get the amfid task port
 */
pid_t hijacksysdiagnose(uint64_t myproc);

/*
 function: find_misvsaci
 
 Use:
 Parses the amfi load address and searches for MISVSACI's offset
 */

uint64_t find_misvsaci(uint64_t load_addr);

/*
 function: amfidestroyer
 
 Use:
 Patches amfid so we can run fakesigned binaries
 */
int amfidestroyer(UInt32 amfipid, uint64_t ourproc);

#endif /* amfidestroyer_h */
