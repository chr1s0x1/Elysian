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
 function: todocreds
 
 Use:
 1. steal/borrow the kernel creds (todo = 0)
 2, revert our tasks creds to default
 
 */
int todocreds(uint64_t kernproc, int todo);

int platform_self(uint64_t ourtask);
#endif /* jbtools_h */
