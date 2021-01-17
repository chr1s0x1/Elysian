//
//  bootstrap.m
//  Elysian
//
//  Created by chris  on 5/19/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/file.h>
#include "bootstrap.h"
#import "utils.h"
#import "jbtools.h"
#import "jelbrekLib.h"

// Incomplete so far
bool createbootstrap(uint64_t kproc) {
    int retval = 0;
    
    // need perms for mkdir
    if(getuid() != 0) {
        LOG("[bootstrap] ?: Getting perms..");
        CredsTool(kproc, 0, 0, NO, YES);
    }
    LOG("[bootstrap] Setting up Bootstrap..");
    mkdir("/Elysian", 0755);
    if(!fileExists("/Elysian")) {
        LOG("[bootstrap] ERR: Failed to create JB folder");
        retval = 2;
        goto out;
    }
    LOG("[bootstrap] Created JB folder");
    chown("/Elysian", 0, 0);
    
    // create bin folder
    
    mkdir("/Elysian/bin", 0755);
    if(!fileExists("/Elysian/bin")) {
        LOG("[bootstrap] ERR: Failed to create bin foler");
        retval = 3;
        goto out;
    }
    LOG("[bootstrap] Created bin folder");
    chown("Elysian/bin", 0, 0);
    
    // LOG("[bootstrap] ?: Copying over JB files..");
    
    // copy over SSH files
    

    LOG("[bootstrap] Bootstrap returned: %d", retval);
    return true;
    
    out:
    LOG("[bootstrap] Bootstrap returned with error: %d", retval);
    CredsTool(0, 0, 1, NO, NO);
    return false;
}
