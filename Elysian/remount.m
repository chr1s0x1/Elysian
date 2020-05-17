//
//  remount.m
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
#include <sys/file.h>
#include <sys/snapshot.h>


#include "IOKit/IOKit.h"
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

bool RenameSnapRequired(void) {
    int fd = open("/", O_RDONLY, 0);
    if(fd < 0) {
        close(fd);
        LOG("ERR: Can't open /, are we root?");
        return 1;
    }
    int count = list_snapshots("/");
    return count == -1 ? YES : NO;
}

uint64_t FindNewMount(uint64_t vnode) {
    LOG("Finding disk0s1s1 in new mount path");
    char checkname[20];
    uint64_t vnodename = rk64(vnode + 0xb8);
    kread(vnodename, checkname, 20);
    LOG("Vnode: %s", checkname);
    uint64_t mount = rk64(vnode + 0xd8);
    while(mount != 0) {
        char newmountname[20];
        uint64_t vp = rk64(mount + 0x980);
        if(vp == 0 || !ADDRISVALID(vp)) {
            LOG("ERR: Couldn't get vp");
            return 1;
        }
        uint64_t vp_name = rk64(vp + 0xb8);
        kread(vp_name, newmountname, 20);
        LOG("Got vnode: %s", newmountname);
        if(strncmp(newmountname, "disk0s1s1", 20) == 0) {
            LOG("Found disk0s1s1");
            return vp;
        }
        mount = rk64(mount + 0x0);
    }
    
    LOG("ERR: Couldn't find disk0s1s1");
    return 1;
}

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
    uint64_t rootvnode = lookup_rootvnode();
    uint64_t rvnodename = rk64(rootvnode + 0xb8);
    kread(rvnodename, vnodename, 20);
        if(!ADDRISVALID(rootvnode) || strncmp(vnodename, "disk0s1s1", 20) != 0) {
            LOG("ERR: Failed to find rootvnode");
            return 1;
        }
    LOG("Got rootvnode");
    
    bool rename = RenameSnapRequired();
    if(rename == NO) {
        LOG("Snapshot already renamed");
        goto renamed;
    }

    // grab kern creds to mount RootFS
    int ret = CredsTool(kernproc, 0, YES);
    if(ret == 1) {
        LOG("ERR: Failed to get kernel creds");
        CredsTool(0, 1, NO);
        return 1;
    }
    
    /* find the BootSnapshot  */
    char *Snapshot = find_system_snapshot();
    if(Snapshot == NULL) {
        LOG("ERR: Failed to get Boot Snapshot");
        return _NOSNAP;
    }
    LOG("Snapshot: %s", Snapshot);
    
    // check if mount path already exists and attempt to remove it
    if(fileExists("/var/rootmnt")) {
        LOG("?: Found (old) mount path, removing..");
    try: rmdir("/var/rootmnt");
        if(fileExists("/var/rootmnt")) {
            LOG("ERR: Couldnt remove mount path");
        }
    }
    // setup mount path for mounting rootvnode
    kern_return_t dir = mkdir("/var/rootmnt", 0755);
    if(dir != KERN_SUCCESS) {
        LOG("ERR: Failed to create mount path");
        CredsTool(0, 1, NO);
        return 1;
    }
    LOG("Created mount path");
    chown("/var/rootmnt", 0, 0);
    
    let mntpath = strdup("/var/rootmnt");
    
    // get dev flags
    let spec = rk64(rootvnode + 0x78); // 0x78 = specinfo
    let specflags = rk32(spec + 0x10); // 0x10 = specinfo flags
    LOG("Found spec flags: %u", specflags);
    
    // setting spec flags to 0
    wk32(spec + 0x10, 0);
    
    // setup mount args
    var fspec = strdup("/dev/disk0s1s1");
    struct hfs_mount_args mntargs = {};
    mntargs.fspec = fspec;
    mntargs.hfs_mask = 1;
    gettimeofday(nil, &mntargs.hfs_timezone);
    
    // Now for actual mounting of rootFS
    int retval = mount("apfs", mntpath, 0, &mntargs);
    
    free(fspec);
    
    if(retval != 0) {
        return _MOUNTFAILED;
    }
    LOG("Mount returned: %d", retval);
    
    LOG("Succesfully Mounted FS");
    
    int fd = open(mntpath, O_RDONLY);
    if(fd < 0) {
        LOG("ERR: Can't open mount path after mount");
        CredsTool(0, 1, NO);
        return 1;
    }
    close(fd);
    
    unmount(mntpath, MNT_FORCE);
    fspec = strdup("/dev/disk0s1s1");
    mntargs.fspec = fspec;
    retval = mount("apfs", mntpath, 0, &mntargs);
    free(fspec);
    if(retval != 0) {
        LOG("ERR: Failed to mount rootFS in new mount path");
        CredsTool(0, 1, NO);
        return 1;
    }
    LOG("Mount returned (2nd time): %d", retval);
    uint64_t new_mount = lookup_rootvnode();
    uint64_t drop1 = rk64(new_mount - 0xd8); // drop to System
    uint64_t drop = rk64(drop1 - 0x980);
    uint64_t newdisk = FindNewMount(drop);
    if(!ADDRISVALID(newdisk)) {
        LOG("ERR: Couldn't find disk0s1s1 in new mount path");
        return 1;
    }
    uint64_t newname = rk64(newdisk + 0xb8);
    kread(newname, vnodename, 20);
    LOG("Found vnode (should be root): %s", vnodename);
    
    /* Patch the snapshot so XNU can't boot from it */
    
    // 1. Remove snapshot flags
    uint64_t nodelist = rk64(newdisk + (UInt64)0x40);
    if(!ADDRISVALID(nodelist)) {
        LOG("ERR: Uh.. there's no vnodelist");
        return 1;
    }
    while(nodelist != 0) {
    uint64_t nodename = rk64(nodelist + 0xb8);
    let namelen = (int)(kstrlen(nodename));
    let prefix = "com.apple.os.update-";
    char name[sizeof(namelen)];
    kread(nodename, name, namelen);
    LOG("Got vnode name: %s", name);
    if(strncmp(prefix, name, 30) == 0) {
        uint64_t vdata = rk64(nodelist + 0xe0);
        let snapflag = rk32(vdata + 0x54);
        LOG("Got Snapshot flags: %u", snapflag);
        // remove snap flags
        wk32(vdata + 0x54, snapflag & ~0x40);
        }
        usleep(1000);
        nodelist = rk64(nodelist + (UInt64)0x20);
        if(nodelist == 0 && strncmp(prefix, name, 30) != 0) {
            LOG("ERR: Failed to find snapshot for rename");
            return 1;
        }
    }
    
    // 2. rename the snapshot
    
    return 0;
    
renamed:
    
    return 0;
}
