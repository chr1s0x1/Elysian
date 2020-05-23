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
#import "kernel_memory.h"
#import "csblobmanipulate.h"


int csblobmanipulate(const char *macho) {
    LOG("[csblob] Setting gen count for %s..", macho);
    // find the vnode
    uint64_t vnode = vnode_finder(macho, NULL, NO);
    if(!ADDRISVALID(vnode)) {
        return 1;
    }
    
    return 0;
}
