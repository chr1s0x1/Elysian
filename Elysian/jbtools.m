//
//  jbtools.m
//  Elysian
//
//  Created by chris  on 4/27/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/file.h>
#include <spawn.h>
#include <dlfcn.h>
#include <sys/cdefs.h>



#import "jelbrekLib.h"
#import "utils.h"
#import "offsets.h"
#import "kernel_memory.h"
#import "jbtools.h"

let TF_PLATFORM = (UInt32)(0x00000400);

let CS_VALID = (UInt32)0x00000001;
let CS_GET_TASK_ALLOW = (UInt32)(0x00000004);
let CS_INSTALLER = (UInt32)(0x00000008);

let CS_HARD = (UInt32)(0x00000100);
let CS_KILL = (UInt32)(0x00000200);
let CS_RESTRICT = (UInt32)(0x00000800);

let CS_PLATFORM_BINARY = (UInt32)(0x04000000);
let CS_DEBUGGED = (UInt32)(0x10000000);


int CredsTool(uint64_t proc, int todo, bool set) {
    if(todo > 1 || todo < 0) {
        LOG("[credstool] ERR: Integer 'todo' must be 0 or 1");
        return 1;
    }else if(proc == 0 && todo == 0) {
        LOG("[credstool] ERR: Stealing creds requires proc");
        return 1;
    }else if(!ADDRISVALID(proc) && todo == 0) {
        LOG("[credstool] ERR: Proc given is invalid!");
        return 1;
    }
    //------- for reverting creds -------\\
    // creds
    let our_orig_t = find_self_task();
    let our_orig_p = rk64(our_orig_t + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    let orig_creds = rk64(our_orig_p + 0x100);
    // label
    let orig_label = rk64(orig_creds + 0x78);
    // svuid
    let orig_svuid = rk32(orig_creds + 0x20);

    if(todo == 0) {
        // find creds..
    LOG("[credstool] Borrowing creds..");
    LOG("[credstool] Given proc: 0x%llx", proc);
    let our_task = find_self_task();
    let our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
    LOG("[credstool] Our proc: 0x%llx", our_proc);
        if(!ADDRISVALID(our_proc)) {
            LOG("[credstool] ERR: Couldn't get our proc!");
            return 1;
        }
    let our_creds = rk64(our_proc + 0x100);
    let our_label = rk64(our_creds + 0x78);
    let s_ucred = rk64(proc + 0x100);
    // steal >:)
    wk64(our_creds + 0x78, rk64(s_ucred + 0x78));
    wk32(our_creds + 0x20, (UInt32)(0));
    wk64(our_proc + 0x100, s_ucred);
    LOG("[credstool] Got given proc creds");
        // setuid ??
        if(set == YES) {
    LOG("[credstool] Setting uid to 0..");
    setuid(0);
    setuid(0);
    wk64(our_creds + 0x78, our_label);
    if(getuid() != 0) {
    LOG("[credstool] ERR: Failed to set uid to 0");
    return 1;
            }
    LOG("[credstool] Our uid is %d", getuid());
        }
    LOG("[credstool] Done");
    return 0;
    } else if (todo == 1) {
        // revert creds..
        LOG("[credstool] Reverting creds..");
        let our_task = find_self_task();
        let our_proc = rk64(our_task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
        LOG("[credstool] Our proc: 0x%llx", our_proc);
        let our_creds = rk64(our_proc + 0x100);
        wk64(our_proc + 0x100, orig_creds);
        let our_label = rk64(our_creds + 0x78);
        wk64(our_creds + 0x78, orig_label);
        let our_svuid = rk32(our_creds + 0x20);
        wk32(our_creds + 0x20, orig_svuid);
        setuid(501);
        if(getuid() != 501) {
            LOG("[credstool] ERR: Failed to revert our uid");
            return 1;
        }
        LOG("[credstool] Reverted creds");
        return 0;
    }
    return 0;
}

int PlatformTask(uint64_t task) {
    if(!ADDRISVALID(task)) {
        LOG("[platform] ERR: Invalid task");
        return 1;
    }
    LOG("[platform] Platforming task..");
    let our_proc = rk64(task + koffset(KSTRUCT_OFFSET_TASK_BSD_INFO));
#if __arm64e__
    let our_flags = rk32(task + 0x3C0);
    wk32(task + 0x3C0, our_flags | TF_PLATFORM);
#else
    let our_flags = rk32(task + 0x3B8);
    wk32(task + 0x3B8, our_flags | TF_PLATFORM);
#endif
    var our_csflags = rk32(our_proc + 0x298);
    our_csflags = our_csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW;
    our_csflags &= ~(CS_RESTRICT | CS_HARD | CS_KILL);
    wk32(our_proc + 0x298, our_csflags);
    LOG("[platform] Platformized task");
    return 0;
}

int Execute(pid_t pid, const char *file, char * const* argv) {
    int status;
    if(!pid) pid = getpid();
    posix_spawn(&pid, file, NULL, NULL, argv, NULL);
    waitpid(pid, &status, 0);
    if(status != 0) {
        LOG("ERR: Failed to run %s", file);
        return status;
    }
    return status;
}

// took this from Apple, Ty Siguza for showing me this
uint64_t lookup_rootvnode() {
    LOG("Finding rootvnode..");
    char rootname[20]; // will store the vnode name
    
    int fd = open("/", O_RDONLY);
    if(fd < 0) {
        LOG("ERR: Can't open '/'");
        return 1;
    }
    // get the fglob from our proc
    uint64_t proc = proc_of_pid(getpid());
    uint64_t fdesc = rk64(proc + koffset(KSTRUCT_OFFSET_PROC_P_FD));
    if(!ADDRISVALID(fdesc)) {
        LOG("ERR: Failed to get fdesc");
        close(fd);
        return 1;
    }
    LOG("Got the fdesc");
    uint64_t fofiles = rk64(fdesc + koffset(KSTRUCT_OFFSET_FILEDESC_FD_OFILES));
    uint64_t fileproc = rk64(fofiles + fd * 8); // * 8 is a pointer in bytes
    uint64_t fglob = rk64(fileproc + koffset(KSTRUCT_OFFSET_FILEPROC_F_FGLOB));
    if(!ADDRISVALID(fglob)) {
        LOG("ERR: Couldn't get fglob");
        close(fd);
        return 1;
    }
    LOG("Got the fglob");
    uint64_t node = rk64(fglob + koffset(KSTRUCT_OFFSET_FILEGLOB_FG_DATA));
    if(!ADDRISVALID(node)) {
        LOG("ERR: This.. doesn't look like a vnode");
        close(fd);
        return 1;
    }
    uint64_t nodename = rk64(node + 0xb8);
    kread(nodename, rootname, 20);
    if(strncmp(rootname, "System", 20) == 0) {
    LOG("Found vnode: %s", rootname);
    LOG("Found rootvnode");
    close(fd);
    return node;
    }
    LOG("ERR: Couldn't find rootvnode");
    close(fd);
    return 1;
}

