//
//  jbtools.m
//  Elysian
//
//  Created by chris  on 4/27/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "utils.h"
#import "kernel_memory.h"
#import "jbtools.h"

int todocreds(uint64_t kernproc, int todo) {
    if(todo > 1 || todo < 0) {
        LOG("ERR: integer todo must be 0 or 1\n");
        return 1;
    }
    if(todo == 0) {
        // find creds..
    LOG("[todocreds] Borrowing kernel creds..\n");
    LOGM("[todocreds] kernel proc: 0x%llx\n", kernproc);
    let our_proc = find_self_task();
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
    LOGM("[todocreds] our uid is %d\n", getpid());
    return 0;
    } else if (todo == 1) {
        // revert creds..
        LOG("[todocreds] Reverting creds..\n");
        let our_proc = find_self_task();
        LOGM("[todocreds] our process: 0x%llx\n", our_proc);
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
