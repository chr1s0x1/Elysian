//
//  jbtools.h
//  Elysian
//
//  Created by chris  on 4/27/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef jbtools_h
#define jbtools_h


/*
 function: CredsTool
 
 Use:
 1. steal/borrow the kernel creds (todo = 0) & setuid to 0 (optional)
 2. revert our tasks creds & uid to default (todo = 1)
 
 */
int CredsTool(uint64_t kernproc, int todo, bool set);

/*
 function: PlatformTask
 
 Use:
 Insert platform flags into task that makes XNU assume task is a Apple certified task & platform our cs flags
 
 */
int PlatformTask(uint64_t task);

/*
 function: Execute
 
 Use:
 A wrapper over posix_spawn that executes a file from "file" with the args "argv" unless argv == NULL
 
 */
int Execute(const char *file, char * const* argv,...);

/*
 function: lookup_rootvnode
 
 Use:
 Finds the root (i.e "/") vnode
 
 */
uint64_t lookup_rootvnode(void);

#endif /* jbtools_h */
