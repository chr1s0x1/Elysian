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

// After renaming the snapshot, trying to grab the disk0s1s1 name from the offset
// 0xb8 = an invalid address.. So we just check if the address is valid to tell
// us if we've renamed the snapshot (valid = NO) (invalid = YES)
bool RenameSnapRequired(void) {
   uint64_t rootvnode = lookup_rootvnode();
   uint64_t vmount = rk64(rootvnode + 0xd8);
   uint64_t dev = rk64(vmount + 0x980);
   uint64_t rvnodename = rk64(dev + 0xb8);
   
   return ADDRISVALID(rvnodename) ? YES : NO;
}

uint64_t FindNewMount(uint64_t vnode) {
   uint64_t vmount = rk64(vnode + 0xd8);
   uint64_t mount = rk64(vmount + 0x0);
    while(mount != 0) {
        char newmountname[20];
        uint64_t vp = rk64(mount + 0x980);
        if(vp != 0) {
        uint64_t vp_name = rk64(vp + 0xb8);
        kread(vp_name, newmountname, 20);
        LOG("Got vnode: %s", newmountname);
        if(strncmp(newmountname, "disk0s1s1", 20) == 0) {
            return mount;
            }
        }
        mount = rk64(mount + 0x0);
    }
    
    return 1;
}

char vnodename[20];

int RemountFS() {
    LOG("Remounting RootFS..");
    // grab kernproc for CredsTool
    uint64_t kernproc = proc_of_pid(0);
    if(!ADDRISVALID(kernproc)) {
        LOG("ERR: Failed to get kernproc");
        return 1;
    }
    LOG("Got kernproc: 0x%llx", kernproc);
   
    bool rename = RenameSnapRequired();
    if(rename == YES) {
        // get disk0s1s1
    uint64_t rootvnode = lookup_rootvnode();
    uint64_t vmount = rk64(rootvnode + 0xd8);
    uint64_t dev = rk64(vmount + 0x980);
    uint64_t rvnodename = rk64(dev + 0xb8);
    kread(rvnodename, vnodename, 20);
        if(!ADDRISVALID(rootvnode) || strncmp(vnodename, "disk0s1s1", 20) != 0) {
            LOG("ERR: Failed to find disk0s1s1");
            return 1;
        }
    LOG("Got vnode: %s", vnodename);

    // grab kern creds to mount RootFS
    int ret = CredsTool(kernproc, 0, NO, YES);
    if(ret == 1) {
        LOG("ERR: Failed to get kernel creds");
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    
    /* find the BootSnapshot  */
    char *Snapshot = find_system_snapshot();
    if(Snapshot == NULL) {
        LOG("ERR: Failed to get Boot Snapshot");
        return 1;
    }
    LOG("Got System Snapshot");
    
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
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    chown("/var/rootmnt", 0, 0);
    
    let mntpath = strdup("/var/rootmnt");
    
    // get dev flags
    let spec = rk64(dev + 0x78); // 0x78 = specinfo
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
       LOG("ERR: MountFS failed!");
       CredsTool(0, 1, NO, NO);
       return 1;
    }
    LOG("Mount returned: %d", retval);
    
    int fd = open(mntpath, O_RDONLY);
    kern_return_t revert = fs_snapshot_revert(fd, Snapshot, 0);
    if(fd < 0 || revert != KERN_SUCCESS) {
        LOG("ERR: Can't open or revert mount path after mount");
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    close(fd);
    
    unmount(mntpath, MNT_FORCE);
    fspec = strdup("/dev/disk0s1s1");
    mntargs.fspec = fspec;
    mntargs.hfs_mask = 1;
    gettimeofday(nil, &mntargs.hfs_timezone);
    retval = mount("apfs", mntpath, 0, &mntargs);
    free(fspec);
    if(retval != 0) {
        LOG("ERR: Failed to mount rootFS in new mount path");
        CredsTool(0, 1, NO, NO);
        return 1;
    }
    LOG("Mount returned (2nd time): %d", retval);
    uint64_t newdisk = FindNewMount(rootvnode);
    if(!ADDRISVALID(newdisk)) {
        LOG("ERR: Couldn't find disk0s1s1 in new mount path");
        return 1;
    }
    LOG("Found disk0s1s1 in new mount path");
    
    /* Patch the snapshot so XNU can't boot from it */
    
    // 1. Remove snapshot flags (loop over vnode list til we find snapshot's)
    uint64_t nodelist = rk64(newdisk + 0x40);
    while(nodelist != 0) {
    uint64_t nodename = rk64(nodelist + 0xb8);
    int namelen = (int)(kstrlen(nodename));
    char prefix[20] = "com.apple.os.update-";
    char name[namelen];
    kread(nodename, name, namelen);
      LOG("Got vnode name: %s", name);
       if(strncmp(name, prefix, sizeof(prefix)) == 0) {
        let vdata = rk64(nodelist + 0xe0);
        let snapflag = rk32(vdata + 0x31);
        LOG("Got Snapshot flags: %u", snapflag);
        // remove snap flags
        wk32(vdata + 0x31, snapflag & ~0x40);
        LOG("Removed Snapshot flag");
        // 2. rename the snapshot
        int fd2 = open("/var/rootmnt", O_RDONLY);
        kern_return_t rename = fs_snapshot_rename(fd2, Snapshot, "orig-fs", 0);
        if(fd2 < 0 || rename != KERN_SUCCESS) {
          LOG("ERR: Failed to rename Snapshot");
          CredsTool(0, 1, NO, NO);
          close(fd2);
          return 1;
               }
      // clean up and reboot
        close(fd2);
        unmount(mntpath, 0);
        rmdir(mntpath);
        LOG("Renamed Snapshot, rebooting..");
        usleep(2000);
        reboot(0);
            }
        usleep(1000);
        nodelist = rk64(nodelist + (UInt64)(0x20));
        if(nodelist == 0 && strncmp(prefix, name, sizeof(prefix)) != 0) {
            LOG("ERR: Failed to find snapshot for rename");
            CredsTool(0, 1, NO, NO);
            return 1;
        }
    }
return 0;
} else {
       
// Should go here when we already renamed the snapshot
   LOG("?: Snapshot already renamed");
   LOG("Remounting RootFS as r/w..");
   CredsTool(kernproc, 0, NO, YES);
   uint64_t rootvnode = lookup_rootvnode();
   let vmount = rk64(rootvnode + 0xd8);
   let flag = rk32(vmount + (UInt64)(0x70)) & ~((UInt32)(MNT_NOSUID) | (UInt32)(MNT_RDONLY));
   wk32(vmount + (UInt64)(0x70), flag & ~((UInt32)(MNT_ROOTFS)));
   LOG("Removed mount flags");
   var disk = strdup("/dev/disk0s1s1");
   let update = mount("apfs", "/", MNT_UPDATE, &disk);
   free(disk);
   if(update != 0) {
      LOG("ERR: Failed to update disk0s1s1 as r/w");
      CredsTool(0, 1, NO, NO);
      return 1;
      }
   LOG("Updated mount as r/w? testing..");
   wk32(vmount + 0x70, flag);
    // RootFS is r/w ???
   createFILE("/.Elysian", nil);
   FILE *f = fopen("/.Elysian", "rw");
   if(!fileExists("/.Elysian") || !f) {
      LOG("ERR: Test file doesn't exist or we have no r/w");
      fclose(f);
      CredsTool(0, 1, NO, NO);
      return 1;
   }
   LOG("Created '.Elysian' at '/'");
   fclose(f);
   LOG("Remounted RootFS");
   return 0;
   }
return 0;
}
