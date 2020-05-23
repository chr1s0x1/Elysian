//
//  amfiutils.h
//  Elysian
//
//  Created by chris  on 5/22/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef amfiutils_h
#define amfiutils_h

// Support functions for amfidestroyer
int AmfidSetException(uint64_t amfidport, void *(exceptionHandler)(void*));
void init_amfid_mem(mach_port_t amfid_tp);
void* AmfidRead(uint64_t addr, uint64_t len);
void AmfidWrite_8bits(uint64_t addr, uint8_t val);
void AmfidWrite_32bits(uint64_t addr, uint32_t val);
void AmfidWrite_64bits(uint64_t addr, uint64_t val);
#endif /* amfiutils_h */
