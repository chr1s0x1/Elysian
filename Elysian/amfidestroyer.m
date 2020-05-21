//
//  amfidestroyer.m
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "jelbrekLib.h"
#import "amfidestroyer.h"
#import "kernel_memory.h"

#import "utils.h"

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


int find_amfid() {
    LOG("[find amfid] Looking for amfid..");
    uint64_t proc = rk64(Find_allproc());
    UInt32 amfidpid = 0;
    while(proc != 0) {
        char amfidname[32];
        var pid = rk32(proc + (UInt64)(0x68));
        uint64_t procname = proc + 0x258;
        kread(procname, amfidname, 32);
        if(strncmp(amfidname, "amfid", 32) == 0) {
            LOG("[find amfid] Found amfid! Exiting..");
            amfidpid = pid;
            return amfidpid;
        }
        proc = rk64(proc);
    }
    LOG("[find amfid] ERR: Couldn't find amfid");
    return 1;
}

int amfidestroyer() {
    LOG("[amfid] Let's do this..");
    mach_port_t amfid_task_port = MACH_PORT_NULL;
    // Get amfid's pid
    pid_t amfipid = find_amfid();
    if(amfipid == 1) return 1; // find_amfid() returns "1" if it fails
    LOG("[amfid] Got amfid pid: %d", amfipid);
    // Grab amfid's task port
    task_for_pid(mach_task_self_, amfipid, &amfid_task_port);
    if(!MACH_PORT_VALID(amfid_task_port)) {
        LOG("ERR: Failed to get amfid task port");
        mach_port_destroy(mach_task_self_, amfid_task_port);
        return 1;
    }
    LOG("[amfid] Got amfid task port");
    
    init_amfid_mem(amfid_task_port);
    
    
    
    return 0;
}
