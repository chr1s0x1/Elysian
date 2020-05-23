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

bool createbootstrap() {
    // need perms for mkdir
    if(getuid() != 0) {
        LOG("[boostrap] ?: Getting perms");
        uint64_t kernproc = proc_of_pid(0);
        if(!ADDRISVALID(kernproc)) {
            LOG("[boostrap] ERR: Couldn't get kernproc for perms");
            return 1;
        }
        CredsTool(kernproc, 0, NO, YES);
    }
    LOG("[bootstrap] Setting up Bootstrap..");
    int dir = mkdir("/Elysian", 0755);
    if(dir != 0) {
        LOG("[bootstrap] ERR: Failed to create JB folder");
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    chown("/Elysian", 0, 0);
    // bin
    mkdir("/Elysian/bin", 0755);
    chown("Elysian/bin", 0, 0);
    
    // copy over SSH files
    return true;
}
