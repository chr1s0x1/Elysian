//
//  remount.m
//  Elysian
//
//  Created by chris  on 4/1/20.
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

char name[20];

bool RenameSnapRequired(void) {
    int fd = open("/", O_RDONLY, 0);
    if(fd <= 0) {
        close(fd);
        LOG("ERR: Can't open /, are we root?/n");
        return 1;
    }
    int count = list_snapshots("/");
    return count == -1 ? YES : NO;
}

char *FindBootSnap(void) {
    
    // -- WIP & *currently* not finished *yet* --
    let chosen = IORegistryEntryFromPath(0, "IODeviceTree:/chosen");
    let data = IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);
    IOObjectRelease(chosen);
    let data_ns = (__bridge NSData*)data;
    var ManifestHash = "";
    let buf = (UInt8)(data_ns);
    // sizeof(char) = 1 Byte
    let i = sizeof(char);

    
    return ManifestHash;
}

int MountFS(uint64_t vnode) {
    let mntpath = strdup("/var/rootfsmnt");
    
    // find disk0s1s1
    let devmount = rk64(vnode + 0xd8);
    let devvp = rk64(devmount + 0x980);
    let devname = rk64(devvp + 0xb8);

    kread(devname, name, 20);
    
    LOGM("Got dev vnode: %s\n", name);
    
    // get dev flags
    let spec = rk64(devvp + 0x78); // 0x78 = specinfo
    let specflags = rk32(spec + 0x10); // 0x10 = specinfo flags
    LOGM("Found spec flags: %u\n", specflags);
    
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
    LOGM("Mount returned: %d\n", retval);
    return _MOUNTSUCCESS;
}

uint64_t FindNewMountPath(uint64_t rootvnode) {
    
    return 0;
}

// Credit to Chimera13
  
int RemountFS() {
    LOG("Remounting RootFS..\n");
    // check if we can open "/"
    int file = open("/", O_RDONLY, 0);
    if(file <= 0) {
        LOG("ERR: Can't to open /, are we root?\n");
        return 1;
    }
    
    // get our and kernels proccess
    uint64_t kernel_proc = proc_of_pid(0);
    LOGM("Got kernel proccess: 0x%llx\n", kernel_proc);
    uint64_t our_task = find_self_task();
    uint64_t our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOGM("Got our proc: 0x%llx\n", our_proc);
    
    // Find launchd
    uint64_t launchd_proc = proc_of_pid(1);
    if(launchd_proc == 0) {
        LOG("ERR: Couldn't find launchd process\n");
        return _NOLAUNCHDERR;
    }
    LOGM("Found launchd: 0x%llx\n", launchd_proc);
    
    // find vnode
    uint64_t textvp = rk64(launchd_proc + 0x238); // 0x238 = textvp
    uint64_t vname = rk64(textvp + 0xb8); // 0xb8 = vnode name
    kread(vname, name, 20);
    
    LOGM("Got vnode: %s\n", name);
    
    // find sbin vnode
    uint64_t sbin = rk64(textvp + 0xc0); // 0xc0 = vnode parent
    uint64_t sbinname = rk64(sbin + 0xb8);
    kread(sbinname, name, 20);
    
    LOGM("Got vnode (should be sbin): %s\n", name);
    
    // find rootvnode
    uint64_t rootvnode = rk64(sbin + 0xc0);
    uint64_t rootname = rk64(rootvnode + 0xb8);
    kread(rootname, name, 20);
    
    LOGM("Got vnode (should be root): %s\n", name);
    
    // find vnode flags
    uint64_t vnodeflags = rk32(rootvnode + 0x54); // 0x54 = flags
    LOGM("vnode flags: 0x%llx\n", vnodeflags);
    
    bool required = RenameSnapRequired();
    if(required == NO) {
        LOG("Snapshot already renamed!\n");
        goto renamed;
    }
    
    
    // Gonna need kernel perms for this
    int cred = CredsTool(kernel_proc, 0, YES);
    if(cred == 1) {
        LOG("ERR: Failed to get kernel creds\n");
        CredsTool(0, 1, NO);
        return 1;
    }
    
    const char *BootSnap = FindBootSnap();
    LOGM("Found System Snapshot: %s\n", BootSnap);
    
    // check if theres a old mount dir
    if((BOOL)fileExists("/var/rootfsmnt") == YES) {
        LOG("Found (old) mount path, removing..\n");
    try: rmdir("/var/rootfsmnt");
        if(fileExists("/var/rootfsmnt")) {
            LOG("ERR: Failed to remove (old) mount path\n");
            }
       }
    
    // create dir for mount
     let mntpathSW = "/var/rootfsmnt";
     kern_return_t dir = mkdir(mntpathSW, 0755);
     if(dir != KERN_SUCCESS) {
         LOG("ERR: Failed to create mount path\n");
         CredsTool(0, 1, NO);
         return 1;
     }
    LOG("Created mount path\n");
    chown(mntpathSW, 0, 0);
    
    // Mount FS
    int mount = MountFS(rootvnode);
    if(mount != _MOUNTSUCCESS) {
        LOG("ERR: Failed to mount FS\n");
        CredsTool(0, 1, NO);
        return mount;
    }
    LOG("Succesfully mounted FS\n");
    CredsTool(0, 1, NO);
    
// jump here once we succesfully renamed snap (jump at line 117)
renamed:
    return 0;
}
