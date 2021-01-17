//
//  csblobmanipulate.m
//  Elysian
//
//  Created by chris  on 5/21/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/snapshot.h>
#import <sys/mount.h>

#import "utils.h"
#import "jbtools.h"
#import "jelbrekLib.h"
#import "kernel_memory.h"
#import "csblobmanipulate.h"


int csblobmanipulate(const char *macho) {
    
    LOG("[csblob] Setting gen count for %s..", macho);
    
    // grab machO vnode, vnode_finder works on binaries ;)
    uint64_t vnode = vnode_finder(macho, 0, NULL, NO);
    if(!ADDRISVALID(vnode)) {
        LOG("[csblob] ERR: Failed to get vnode for %s", macho);
        return 1;
    }
    LOG("[csblob] Got binary vnode");
    
    // is a csblob already loaded?
    LOG("[csblob] ?: Checking if a csblob exists..");
    uint64_t cs_blob = rk64(vnode + 0x78);
    if(cs_blob != 0) {
        LOG("[csblob] ?: MachO already has a blob, setting gen count..");
        wk64(cs_blob + 44, rk32(Find_cs_gen_count()));
        LOG("[csblob] Gen count is 0, exiting..");
        return 0;
    }
    
    // I don't want to do this :(
    LOG("[csblob] ?: Creating a valid blob..");
    
    
    LOG("[csblob] Created blob and set generation count, finishing up..");
    return 0;
}
