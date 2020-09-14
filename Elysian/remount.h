//
//  remount.h
//  Elysian
//
//  Created by chris  on 5/6/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef remount_h
#define remount_h


// remount returns
enum remount_ret {
    _NOKERNPROC = 1,
    _NODISK = 2,
    _NONEWDISK = 3,
    _NOKERNCREDS = 4,
    _NOSNAP = 5,
    _NOMNTPATH = 6,
    _MOUNTFAILED = 7,
    _REVERTMNTFAILED = 8,
    _MOUNTFAILED2 = 9,
    _RENAMEFAILED = 10,
    _NOUPDATEDDISK = 11,
    _FSTESTFAILED = 12,
    _RENAMEDSNAP = 13,
    _REMOUNTSUCCESS = 0,
};

struct hfs_mount_args {
    char    *fspec;            /* block special device to mount */
    uid_t    hfs_uid;        /* uid that owns hfs files (standard HFS only) */
    gid_t    hfs_gid;        /* gid that owns hfs files (standard HFS only) */
    mode_t    hfs_mask;        /* mask to be applied for hfs perms  (standard HFS only) */
    u_int32_t hfs_encoding;    /* encoding for this volume (standard HFS only) */
    struct    timezone hfs_timezone;    /* user time zone info (standard HFS only) */
    int        flags;            /* mounting flags, see below */
    int     journal_tbuffer_size;   /* size in bytes of the journal transaction buffer */
    int        journal_flags;          /* flags to pass to journal_open/create */
    int        journal_disable;        /* don't use journaling (potentially dangerous) */
};


/*
 function: RenameSnapRequired
 
 Use:
 Checks if we already renamed the snapshot, if we did, it executes the "else" statement
 */

bool RenameSnapRequired(int espeedon);

/*
 function: FindNewMount
 
 Use:
 Finds disk0s1s1 after we have mounted it in "/var/rootmnt"
 */

uint64_t FindNewMount(uint64_t vnode);

/*
 function : RemountFS
 
 Use:
 New and improved remount code that remounts the RootFS.
 */

int RemountFS(uint64_t kernproc, int espeedmode);
#endif /* remount_h */
