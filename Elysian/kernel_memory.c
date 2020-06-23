//
//  kernel_memory.c
//  sock_port
//
//  Created by Jake James on 7/18/19.
//  Copyright © 2019 Jake James. All rights reserved.
//

#import "kernel_memory.h"
#import "offsets.h"

static mach_port_t tfpzero;
static uint64_t task_self;

void init_kernel_memory(mach_port_t tfp0, uint64_t our_port_addr) {
    tfpzero = tfp0;
    task_self = our_port_addr;
}

void init_read_write(mach_port_t tfp0) {
    tfpzero = tfp0;
}

uint64_t kalloc(vm_size_t size) {
    mach_vm_address_t address = 0;
    mach_vm_allocate(tfpzero, (mach_vm_address_t *)&address, size, VM_FLAGS_ANYWHERE);
    return address;
}

void kfree(mach_vm_address_t address, vm_size_t size) {
    mach_vm_deallocate(tfpzero, address, size);
}

size_t kread(uint64_t where, void *p, size_t size) {
    int rv;
    size_t offset = 0;
    while (offset < size) {
        mach_vm_size_t sz, chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_read_overwrite(tfpzero, where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
        if (rv || sz == 0) {
            printf("[-] error on kread(0x%016llx)\n", where);
            break;
        }
        offset += sz;
    }
    return offset;
}

uint32_t rk32(uint64_t where) {
    uint32_t out;
    kread(where, &out, sizeof(uint32_t));
    return out;
}

uint64_t rk64(uint64_t where) {
    uint64_t out;
    kread(where, &out, sizeof(uint64_t));
    return out;
}

size_t kwrite(uint64_t where, const void *p, size_t size) {
    int rv;
    size_t offset = 0;
    while (offset < size) {
        size_t chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_write(tfpzero, where + offset, (mach_vm_offset_t)p + offset, (int)chunk);
        if (rv) {
            printf("[-] error on kwrite(0x%016llx)\n", where);
            break;
        }
        offset += chunk;
    }
    return offset;
}

void wk32(uint64_t where, uint32_t what) {
    uint32_t _what = what;
    kwrite(where, &_what, sizeof(uint32_t));
}


void wk64(uint64_t where, uint64_t what) {
    uint64_t _what = what;
    kwrite(where, &_what, sizeof(uint64_t));
}

unsigned long kstrlen(uint64_t string) {
    if (!string) return 0;
    
    unsigned long len = 0;
    char ch = 0;
    int i = 0;
    while (true) {
        kread(string + i, &ch, 1);
        if (!ch) break;
        len++;
        i++;
    }
    return len;
}

int kstrcmp(uint64_t string1, uint64_t string2) {
    unsigned long len1 = kstrlen(string1);
    unsigned long len2 = kstrlen(string2);
    
    char *s1 = malloc(len1);
    char *s2 = malloc(len2);
    kread(string1, s1, len1);
    kread(string2, s2, len2);
    
    int ret = strcmp(s1, s2);
    free(s1);
    free(s2);
    
    return ret;
}

int kstrcmp_u(uint64_t string1, char *string2) {
    unsigned long len1 = kstrlen(string1);
    
    char *s1 = malloc(len1);
    kread(string1, s1, len1);
 
    int ret = strcmp(s1, string2);
    free(s1);
    
    return ret;
}

uint64_t find_port(mach_port_name_t port) {
    uint64_t task_addr = rk64(task_self + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    uint64_t itk_space = rk64(task_addr + koffset(KSTRUCT_OFFSET_TASK_ITK_SPACE));
    uint64_t is_table = rk64(itk_space + koffset(KSTRUCT_OFFSET_IPC_SPACE_IS_TABLE));
    
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
    
    uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
    
    return port_addr;
}

uint64_t find_self_task() {
    uint64_t task_self = 0;
    uint64_t task_self_port = find_port(mach_task_self());
    task_self = rk64(task_self_port + koffset(KSTRUCT_OFFSET_IPC_PORT_IP_KOBJECT));
    return task_self;
}
