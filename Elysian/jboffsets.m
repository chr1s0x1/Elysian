//
//  jboffsets.m
//  Elysian
//
//  Created by chris  on 5/7/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "jboffsets.h"
#import "jelbrekLib.h"
#import "kernel_memory.h"
#import "utils.h"

// functions gathered from GatherOffsets()
uint64_t _vnode_lookup;
uint64_t _vnode_put;
uint64_t _vfs_context_current;

int GatherOffsets() {    
LOG("[offsets] Getting offsets..");
int offset = 0;
    
_vnode_lookup = Find_vnode_lookup();
    if(!ADDRISVALID(_vnode_lookup)) {
        LOG("\n[offsets] ERR: Failed to get vnode_lookup offset");
        offset = 1;
        goto fail;
    }
    
    LOG("[offsets] vnode_lookup: 0x%llx", _vnode_lookup);
    
_vnode_put = Find_vnode_put();
    if(!ADDRISVALID(_vnode_put)) {
        LOG("[offsets] ERR: Failed to get vnode_put offset");
        offset = 2;
        goto fail;
    }
    
    LOG("[offsets] vnode_put: 0x%llx", _vnode_put);
    
_vfs_context_current = Find_vfs_context_current();
    if(!ADDRISVALID(_vfs_context_current)) {
        LOG("[offset] ERR: Failed to get vfs_context_current offset");
        offset = 3;
        goto fail;
    }
    
    LOG("[offsets] vfs_context_current: 0x%llx", _vfs_context_current);
    
    // Got all the offsets!
    LOG("[offsets] Offset error count is %d", offset);
    LOG("[offsets] Got all offsets");
    return 0;
    
fail:
    LOG("[offsets] ERR: Failed to get offset %d", offset);
    return 1;
}

