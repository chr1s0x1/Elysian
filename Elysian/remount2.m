//
//  remount2.m
//  Elysian
//
//  Created by chris  on 5/6/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/mount.h>
#include <sys/stat.h>
#include <dirent.h>
#include <errno.h>



#include "IOKit/IOKit.h"
#import <sys/snapshot.h>
#import "utils.h"
#import "remount.h"
#import "jelbrekLib.h"
#import "jbtools.h"
#import "kernel_memory.h"
#include "offsets.h"

/*
 
 I've made this to work on remounting myself without using someone else's code.
 The more I do things myself, the more I learn
 
 Here you go CoolStar ;)
 
 It's not fully complete yet, there is still some things I need to fix & add beforehand.

 */

char vnodename[20];

int Remount13() {
    LOG("Remounting RootFS..");
    // grab kernproc for CredsTool
    uint64_t kernproc = proc_of_pid(0);
    if(!ADDRISVALID(kernproc)) {
        LOG("ERR: Failed to get kernproc");
        return 1;
    }
    LOG("Got kernproc: 0x%llx", kernproc);
        // get rootvnode
        uint64_t rootvnode = Find_rootvnode();
        if(!ADDRISVALID(rootvnode)) {
            LOG("Failed to find rootvnode");
            return 1;
        }
    uint64_t vname = rk64(rootvnode + 0xb8);
    kread(vname, vnodename, 20);
    
    LOG("Got rootvnode: %s", vnodename);
    // grab kern creds to mount RootFS
    int ret = CredsTool(kernproc, 0, YES);
    if(ret == 1) {
        LOG("ERR: Failed to get kernel creds");
        return 1;
    }
    
    // check if mount path already exists and attempt to remove it
    if(fileExists("/var/rootmnt")) {
        LOG("Found (old) mount path, removing..");
    try: rmdir("/var/rootmnt");
        if(fileExists("/var/rootmnt")) {
            LOG("ERR: Couldnt remove mount path");
        }
    }
    // setup mount path for mounting rootvnode
    kern_return_t dir = mkdir("/var/rootmnt", 0755);
    if(dir != KERN_SUCCESS) {
        LOG("ERR: Failed to create mount path");
        return 1;
    }
    LOG("Created mount path");
    chown("/var/rootmnt", 0, 0);
    
    let mntpath = strdup("/var/rootfsmnt");
    
    // get dev flags
    let spec = rk64(rootvnode + 0x78); // 0x78 = specinfo
    let specflags = rk32(spec + 0x10); // 0x10 = specinfo flags
    LOG("Found spec flags: %u", specflags);
    
    // setting spec flags to 0
    wk32(spec + 0x10, 0);
    
    // setup mount args
    let fspec = strdup("/dev/disk0s1s1");
    struct hfs_mount_args mntargs = {};
    mntargs.fspec = fspec;
    mntargs.hfs_mask = 1;
    gettimeofday(nil, &mntargs.hfs_timezone);
    
    // Now for actual mounting of rootFS
    let retval = mount("apfs", mntpath, 0, &mntargs);
    
    free(fspec);
    
    if(retval != 0) {
        return _MOUNTFAILED;
    }
    LOG("Mount returned: %d", retval);
    
    LOG("Succesfully Mounted FS");

    /* Now we need to find the BootSnapshot to rename */
    uint64_t Snapshot = find_snapshot_string();
    if(!ADDRISVALID(Snapshot)) {
        LOG("ERR: Failed to get BootSnapshot");
        return 1;
    }
    LOG("Got BootSnapshot");
    
    // patch snapshot so XNU can't boot from it
    
    
    return 0;
}
