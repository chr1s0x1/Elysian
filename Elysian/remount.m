//
//  remount.m
//  Elysian
//
//  Created by chris  on 4/1/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "utils.h"
#import "remount.h"
#import "jelbrekLib.h"
#import "kernel_memory.h"
#include "offsets.h"
  
int remountFS() {
    bool renamed_snap = NO;
    
    LOG("Remounting RootFS..\n");
  // check if we already renamed snapshot
    if(renamed_snap == YES){
        LOG("Snapshot already renamed\n");
        goto next_step;
    }
    // check if we can open "/"
    int file = open("/", O_RDONLY, 0);
    if(file <= 0) {
        printf("Failed to open /, are we root?\n");
    }
    
    int snaps = list_snapshots("/");
    if(snaps < 0) {
        LOG("Failed to find snapshots\n");
        return _NOSNAPS;
    }
    LOG("Found System snapshot(s)\n");
    
next_step:
    return 0;
}
