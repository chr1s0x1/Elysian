//
//  kernel.h
//  Brandon Azad
//
#ifndef OOB_TIMESTAMP__KERNEL__H_
#define OOB_TIMESTAMP__KERNEL__H_

#include <mach/mach.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef KERNEL_EXTERN
#define extern KERNEL_EXTERN
#endif

/*
 * kernel_base_address
 *
 * Description:
 * 	The kernel base address. This is usually 0xfffffff007004000 plus the kASLR slide.
 */
extern uint64_t kernel_base_address;

/*
 * kernel_slide
 *
 * Description:
 * 	The kASLR slide. This is the difference between the static kernel base address and the
 * 	runtime location of the kernel base.
 */
extern uint64_t kernel_slide;

/*
 * current_task
 *
 * Description:
 * 	The address of the current process's task struct in kernel memory.
 */
extern uint64_t current_task;

/*
 * kernel_task
 *
 * Description:
 * 	The address of the real kernel_task struct in kernel memory.
 */
extern uint64_t kernel_task;

/*
 * kernproc
 *
 * Description:
 * 	The address of the kernel's proc struct in kernel memory.
 */
extern uint64_t kernproc;

/*
 * struct kernel_all_image_info_addr
 *
 * Description:
 * 	The struct pointed to by kernel_task TASK_DYLD_INFO all_image_info_addr. This struct
 * 	contains fields that are helpful to regain capabilities after the initial exploit has
 * 	finished.
 */
struct kernel_all_image_info_addr {
	// A magic value to identify this structure.
#define KERNEL_ALL_IMAGE_INFO_ADDR_MAGIC 'KINF'
	uint32_t kernel_all_image_info_addr_magic;
	// The size of this structure.
	uint32_t kernel_all_image_info_addr_size;
	// The kernel base address.
	uint64_t kernel_base_address;
	// The address of kernproc. This is used to walk the process list.
	uint64_t kernproc;
	// The address of the page used for the PAC bypass. This is used to reconstruct the kernel
	// PAC bypass.
	uint64_t kernel_pac_bypass_page;
};

/*
 * kernel_all_image_info_addr
 *
 * Description:
 * 	The address of the kernel_all_image_info_addr struct.
 */
extern uint64_t kernel_all_image_info_addr;

/*
 * kernel_init
 *
 * Description:
 * 	Try to grab the kernel task port and initialize variables for a pre-exploited system.
 *
 * 	The kernel task port should export additional information in task_info(TASK_DYLD_INFO). The
 * 	all_image_info_addr field should be a pointer to a page of kernel memory containing a
 * 	kernel_all_image_info_addr struct at the start. The all_image_info_size field should
 * 	contain the kASLR slide.
 */
bool kernel_init(void);

/*
 * kernel_ipc_port_lookup
 *
 * Description:
 * 	Look up the ipc_entry, ipc_port, and ip_kobject for the specified Mach port name in the
 * 	given task.
 */
bool kernel_ipc_port_lookup(uint64_t task, mach_port_name_t port_name,
		uint64_t *ipc_entry, uint64_t *ipc_port, uint64_t *ip_kobject);
/*
 * kernel_current_thread
 *
 * Description:
 * 	Returns the address of the thread struct for the current thread.
 */
uint64_t kernel_current_thread(void);

#undef extern

#endif
