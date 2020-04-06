//
//  remount.m
//  Elysian
//
//  Created by chris  on 4/1/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <inttypes.h>
#import "utils.h"
#import "remount.h"
#import "jelbrekLib.h"
#import "kernel_memory.h"
#include "offsets.h"

bool renameSnapRequired() {
    int fd = open("/", O_RDONLY, 0);
    if(fd < 0) {
        LOG("ERR: Failed to open /, are we root?");
        return 1;
    }
    int count = list_snapshots("/");
    return count == -1 ? YES : NO;
}


// Credit to Chimera13
  
int remountFS() {
    LOG("Remounting RootFS..\n");
    // check if we can open "/"
    int file = open("/", O_RDONLY, 0);
    if(file <= 0) {
        printf("ERR: Failed to open /, are we root?\n");
    }
    
    // Find launchd
    uint64_t launchd_proc = proc_of_pid(1);
    if(launchd_proc == 0) {
        LOG("ERR: Couldn't find launchd process\n");
        return _NOLAUNCHDERR;
    }
    LOGM("Found launchd: 0x%llx\n", launchd_proc);
    
    // find vnode
    uint64_t textvp = rk64(launchd_proc + 0x238); // 0x238 = textvp
    uint64_t nameptr = rk64(textvp + 0xb8); // 0xb8 = vnode name
    char name[20];
    kread(nameptr, name, 20);
    
    LOGM("Got vnode: %s\n", name);
    
    // find rootvnode
    uint64_t sbin = rk64(textvp + 0xc0); // 0xc0 = vnode parent
    uint64_t rootvnode = rk64(sbin + 0xc0);
    uint64_t rootname = rk64(rootvnode + 0xb8);
    kread(rootname, name, 20);
    
    LOGM("Got vnode (should be root): %s\n", name);
    
    // check if we need to rename snapshot
    bool renameRequired = renameSnapRequired();
    if(renameRequired == NO) {
        LOG("Snapshot already renamed!\n");
        goto next_step;
    }
    
    // find vnode flags
    uint64_t vnodeflage = rk64(rootvnode + 0x54); // 0x54 = flags
    LOGM("vnode flags: 0x%llx\n", vnodeflage);
    
    // Mount vnode
    
    
    /*                                      will uncomment this later
    int snaps = list_snapshots("/");
    if(snaps < 0) {
        LOG("Failed to find snapshots\n");
        return _NOSNAPS;
    }
    LOG("Found System snapshot(s)\n");
    */
next_step:
    return 0;
}
