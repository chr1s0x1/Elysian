//
//  amfidestroyer.m
//  Elysian
//
//  Created by chris  on 5/20/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <spawn.h>

#import "jelbrekLib.h"
#import "amfidestroyer.h"
#import "kernel_memory.h"
#import "jbtools.h"
#import "utils.h"
#import "amfiutils.h"


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
    char const *argv[] = {"sysdiagnose", NULL};
    posix_spawn(&syspid, "/usr/bin/sysdiagnose", NULL, NULL, argv, NULL);
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
    mach_port_t amfid_task_port = MACH_PORT_NULL;
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
    task_for_pid(mach_task_self_, amfipid, &amfid_task_port);
    if(!MACH_PORT_VALID(amfid_task_port)) {
        LOG("ERR: Failed to get amfid task port");
        mach_port_destroy(mach_task_self_, amfid_task_port);
        return 1;
    }
    LOG("[amfid] Got amfid task port");
    
    // for AmfidWrite, AmfidRead etc.
    init_amfid_mem(amfid_task_port);
    
    
    // clean up
    kill(syspid, SIGKILL);
    return 0;
}
