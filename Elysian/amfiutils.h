//
//  amfiutils.h
//  Elysian
//
//  Created by chris  on 5/22/20.
//  Copyright © 2020 chr1s_0x1. All rights reserved.
//

#ifndef amfiutils_h
#define amfiutils_h
#include "include/cs_blob.h"

#define amfid_MISValidateSignatureAndCopyInfo_import_offset 0x4150
uint8_t MISVSACI_actual_offset;
static mach_port_t amfid_task_port;

// Support functions for amfidestroyer
uint64_t binary_load_address(mach_port_t tp);
int AmfidSetException(mach_port_t amfidport, void *(exceptionHandler)(void*));
void init_amfid_mem(mach_port_t amfid_tp);
void* AmfidRead(uint64_t addr, uint64_t len);
void AmfidWrite_8bits(uint64_t addr, uint8_t val);
void AmfidWrite_32bits(uint64_t addr, uint32_t val);
void AmfidWrite_64bits(uint64_t addr, uint64_t val);

// needed for load_binary_address
kern_return_t mach_vm_region(vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *infoCnt, mach_port_t *object_name);

// cdhash stuff
uint32_t swap_uint32( uint32_t val );
uint32_t read_magic(FILE* file, off_t offset);
void *load_bytes(FILE *file, off_t offset, size_t size);
uint8_t *getCodeDirectory(const char* name);
static unsigned int hash_rank(const CodeDirectory *cd);
int get_hash(const CodeDirectory* directory, uint8_t dst[CS_CDHASH_LEN]);
int parse_superblob(uint8_t *code_dir, uint8_t dst[CS_CDHASH_LEN]);
#endif /* amfiutils_h */
