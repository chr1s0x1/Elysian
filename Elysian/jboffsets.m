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
#import "utils.h"

int GatherOffsets() {    
LOG("[offsets] Getting offsets..");
    
uint64_t vnode_lookup = Find_vnode_lookup();
    if(!ADDRISVALID(vnode_lookup)) {
        LOG("[offsets] ERR: Failed to get vnode_lookup offset");
        goto fail;
    }
    LOG("[offsets] vnode_lookup: 0x%llx", vnode_lookup);
    
uint64_t vnode_put = Find_vnode_put();
    if(!ADDRISVALID(vnode_put)) {
        LOG("[offsets] ERR: Failed to get vnode_put offset");
        goto fail;
    }
    LOG("[offsets] vnode_put: 0x%llx", vnode_put);
    
uint64_t vfs_context_current = Find_vfs_context_current();
    if(!ADDRISVALID(vfs_context_current)) {
        LOG("[offset] ERR: Failed to get vfs_context_current offset");
        goto fail;
    }
    LOG("[offsets] vfs_context_current: 0x%llx", vfs_context_current);
    
    // Got all the offsets!
    LOG("[offsets] Succesfully got all offsets");
    return 0;
    
fail:
    LOG("[offsets] ERR: Failed to get some offsets");
    return 1;
}


