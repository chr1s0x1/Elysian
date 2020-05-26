//
//  amfiutils.h
//  Elysian
//
//  Created by chris  on 5/22/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef amfiutils_h
#define amfiutils_h


#define amfid_MISValidateSignatureAndCopyInfo_import_offset 0x4150
static mach_port_t amfid_task_port;

// Support functions for amfidestroyer
uint64_t binary_load_address(mach_port_t tp);
int AmfidSetException(uint64_t amfidport, void *(exceptionHandler)(void*));
void init_amfid_mem(mach_port_t amfid_tp);
void* AmfidRead(uint64_t addr, uint64_t len);
void AmfidWrite_8bits(uint64_t addr, uint8_t val);
void AmfidWrite_32bits(uint64_t addr, uint32_t val);
void AmfidWrite_64bits(uint64_t addr, uint64_t val);

// needed for load_binary_address
kern_return_t mach_vm_region(vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *infoCnt, mach_port_t *object_name);
#endif /* amfiutils_h */
