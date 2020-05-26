//
//  amfiutils.m
//  Elysian
//
//  Created by chris  on 5/22/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <pthread.h>
#include <mach-o/loader.h>
#include <mach/mach.h>

#import "kernel_memory.h"
#import "utils.h"
#import "amfiutils.h"

uint64_t binary_load_address(mach_port_t tp) {
    kern_return_t err;
    mach_msg_type_number_t region_count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object_name = MACH_PORT_NULL; /* unused */
    mach_vm_size_t target_first_size = 0x1000;
    mach_vm_address_t target_first_addr = 0x0;
    struct vm_region_basic_info_64 region = {0};
    printf("[+] About to call mach_vm_region\n");
    err = mach_vm_region(tp,
                         &target_first_addr,
                         &target_first_size,
                         VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&region,
                         &region_count,
                         &object_name);
    
    if (err != KERN_SUCCESS) {
        printf("[-] Failed to get the region: %s\n", mach_error_string(err));
        return -1;
    }
    printf("[+] Got base address\n");
    
    return target_first_addr;
}

void init_amfid_mem(mach_port_t amfid_tp) {
    amfid_task_port = amfid_tp;
}

void* AmfidRead(uint64_t addr, uint64_t len) {
    kern_return_t ret;
    vm_offset_t buf = 0;
    mach_msg_type_number_t num = 0;
    ret = mach_vm_read(amfid_task_port, addr, len, &buf, &num);
    
    if (ret != KERN_SUCCESS) {
        printf("[-] amfid read failed (0x%llx)\n", addr);
        return NULL;
    }
    uint8_t* outbuf = malloc(len);
    memcpy(outbuf, (void*)buf, len);
    mach_vm_deallocate(mach_task_self(), buf, num);
    return outbuf;
}

void AmfidWrite_8bits(uint64_t addr, uint8_t val) {
    kern_return_t err = mach_vm_write(amfid_task_port, addr, (vm_offset_t)&val, 1);
    if (err != KERN_SUCCESS) {
        printf("[-] amfid write failed (0x%llx)\n", addr);
    }
}

void AmfidWrite_32bits(uint64_t addr, uint32_t val) {
    kern_return_t err = mach_vm_write(amfid_task_port, addr, (vm_offset_t)&val, 4);
    if (err != KERN_SUCCESS) {
        printf("[-] amfid write failed (0x%llx)\n", addr);
    }
}


void AmfidWrite_64bits(uint64_t addr, uint64_t val) {
    kern_return_t err = mach_vm_write(amfid_task_port, addr, (vm_offset_t)&val, 8);
    if (err != KERN_SUCCESS) {
        printf("[-] amfid write failed (0x%llx)\n", addr);
    }
}
