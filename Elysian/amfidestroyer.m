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

int AmfidSetException(mach_port_t amfidport, void *(exceptionHandler)(void*)) {
    if(!MACH_PORT_VALID(amfidport)) {
        LOG("[exception] ERR: amfid task port given is invalid");
        return 1;
    }
    
    LOG("[exception] Going to replace amfid's exception port..");
    // add an insert right
    mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &AMFID_ExceptionPort);
    mach_port_insert_right(mach_task_self_, AMFID_ExceptionPort, AMFID_ExceptionPort, (mach_msg_type_name_t)(MACH_MSG_TYPE_MAKE_SEND));
    // did we add an insert right?
    if(!MACH_PORT_VALID(AMFID_ExceptionPort)) {
        LOG("[exception] ERR: Couldn't insert a port right");
        mach_port_destroy(mach_task_self_, AMFID_ExceptionPort);
        return 1;
    }
    LOG("[exception] Inserted a port right");
    
    // replace exception port with ours
    kern_return_t ret = task_set_exception_ports(amfidport, (exception_mask_t)(EXC_MASK_BAD_ACCESS), AMFID_ExceptionPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
    if(ret != KERN_SUCCESS) {
        LOG("[exception] ERR: Couldn't replace amfid exception port!");
        mach_port_destroy(mach_task_self_, AMFID_ExceptionPort);
        return 1;
    }
    LOG("[exception] Replaced amfid's exception port");
    
    // setup a new thread where to handle the exceptions
    pthread_create(&exceptionThread, NULL, exceptionHandler, NULL);
    LOG("[exception] We're done here, exiting..");
    return 0;
}

pid_t hijacksysdiagnose() {
    LOG("[sys] Hijacking sysdiagnose..");
    // find sysdiagnose's pid
    pid_t syspid;
    char const *args[] = {"sysdiagnose", NULL};
    posix_spawn(&syspid, "/usr/bin/sysdiagnose", NULL, NULL, (char **)args, NULL);
    // get the proc from syspid
    uint64_t sysproc = proc_of_pid((UInt32)(syspid));
    if(!ADDRISVALID(sysproc)) {
        LOG("[sys] ERR: sysdiagnose proc is invalid");
        return 1;
    }
    LOG("[sys] Got sysdiagnose proc: 0x%llx", sysproc);
    
    // grab sysdiagnose's creds and entitlements
    // was gonna use CredsTool, but it also borrows the creds
    // which we don't need so..
    uint64_t myproc = proc_of_pid(getpid());
    uint64_t ourcreds = rk64(myproc + 0x100);
    uint64_t syscred = rk64(sysproc + 0x100);

    let ents = rk64(rk64(ourcreds + 0x78) + 0x8);
    let sysents = rk64(rk64(syscred + 0x78) + 0x8);
    wk64(rk64(ourcreds + 0x78) + 0x8, sysents);
    LOG("[sys] Got sysdiagnose creds, returning..");
    return syspid;
}

int amfidestroyer(UInt32 amfipid) {
    LOG("[amfid] Let's do this..");
    mach_port_t amfid_task = MACH_PORT_NULL;
    
    if(amfipid == 0) return 1;
    
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
        LOG("ERR: Unable to get amfid task port");
        mach_port_destroy(mach_task_self_, amfid_task);
        return 1;
    }
    LOG("[amfid] Got amfid task port: 0x%x", amfid_task);
    
    // for AmfidWrite, AmfidRead etc.
    init_amfid_mem(amfid_task);
    
    // get the load address
    uint64_t amfi_load = binary_load_address(amfid_task);
    if(amfi_load == 0) {
        LOG("[amfid] ERR: Couldn't find amfid load address");
        return 1;
    }
    LOG("[amfid] Found amfid load address");
    
    /*-------- now for patching amfi --------*/
    
    LOG("[amfid patch] ?: Applying amfid patches..");
    
    // 1. Set exception handler
    int set = AmfidSetException(amfid_task, AMFIDExceptionHandler);
    if(set != 0) {
        LOG("[amfid patch] ERR: Couldn't set exception handler!");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    LOG("[amfid patch] 1/3 - Successfully set exception handler");
    
    // check if we can read MISValidateSignatureAndCopyInfo
    mach_vm_size_t sz;
    kern_return_t kr = mach_vm_read_overwrite(amfid_task, amfi_load+amfid_MISValidateSignatureAndCopyInfo_import_offset, 8, (mach_vm_address_t)&origAMFID_MISVSACI, &sz);
     if(kr != KERN_SUCCESS) {
        LOG("[amfid patch] ERR: Couldn't read MISVSACI");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    
    // 2. Make MISVSACI r/w for us
    vm_address_t misvsaci_page = (amfi_load + (UInt64)(amfid_MISValidateSignatureAndCopyInfo_import_offset)) & ~vm_page_mask;
    if(misvsaci_page == 0) {
        LOG("[amfid patch] ERR: MISVSACI page is invalid!");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }                                           // remove vm protection flags
    kr = vm_protect(amfid_task, misvsaci_page, vm_page_size, 0, VM_PROT_READ | VM_PROT_WRITE);
    if(kr != KERN_SUCCESS) {
        LOG("[amfid patch] ERR: Couldn't make MISVSACI r/w");
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    LOG("[amfid patch] 2/3 - Made MISVSACI page r/w");
    
    // 3. patch up amfid to crash
    AmfidWrite_64bits(amfi_load + amfid_MISValidateSignatureAndCopyInfo_import_offset, 0x4141414141414141);
    LOG("[amfid patch] 3/3 - MISVSACI is now 0x41");
    
    /*---------- End of patch ----------*/
    
    LOG("[amfid] Mission complete, cleaning up..");
    // clean up
    kill(syspid, SIGKILL);
    CredsTool(0, 1, NO, NO);
    return 0;
}
