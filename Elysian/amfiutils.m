//
//  amfiutils.m
//  Elysian
//
//  Created by chris  on 5/22/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "kernel_memory.h"
#import "utils.h"
#import "amfiutils.h"

static mach_port_t amfid_task_port;
pthread_t exceptionThread;
static mach_port_name_t AMFID_ExceptionPort = MACH_PORT_NULL;
uint64_t origAMFID_MISVSACI = 0;
uint64_t amfid_base;

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

// not done yet
int AmfidSetException(uint64_t amfidport, void *(exceptionHandler)(void*)) {
    if(!MACH_PORT_VALID(amfidport) || !ADDRISVALID(amfidport)) {
        LOG("[exception] ERR: amfid port given is invalid");
        return 1;
    }
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &AMFID_ExceptionPort);
    mach_port_insert_right(mach_task_self(), AMFID_ExceptionPort, AMFID_ExceptionPort, MACH_MSG_TYPE_MAKE_SEND);
    
    return 0;
}
