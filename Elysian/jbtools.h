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
 1. steal/borrow the given proccreds (todo = 0) & setuid to 0 (optional)
 2. revert our tasks creds & uid to default (proc = 0 && todo = 1)
 
 */
int CredsTool(uint64_t proc, int todo, bool ents, bool set);

/*
 function: EscalateTask
 
 Use:
 Insert platform flags into task that makes XNU assume task is a Apple certified task & escalate our cs flags
 
 */
int EscalateTask(uint64_t task);

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

/*
 function: vnode_finder
 
 Use:
 Finds the vnode "nodename" in "path" or from "givenproc", set "givenproc" to 0 if you want to find the vnode in "path"
 
 - if mountype == YES (loops over mount vnodes til it finds the right vnode or fails)
 
 - if mountype == NO (checks if we have the right node from fglob then loops over parent nodes til it finds the right vnode or fails)
 
 */
uint64_t vnode_finder(const char *path, uint64_t givenproc, const char *nodename, BOOL mountype);

#endif /* jbtools_h */
