//
//  kernel.c
//  Brandon Azad
//
#define KERNEL_EXTERN
#include "kernel.h"

#include <unistd.h>

#include "kernel_memory.h"
#include "log.h"
#include "parameters.h"

bool
kernel_init() {
	// Try to grab the kernel task port as host special port 4.
	if (kernel_task_port == MACH_PORT_NULL) {
		mach_port_t host = mach_host_self();
		host_get_special_port(host, 0, 4, &kernel_task_port);
		mach_port_deallocate(mach_task_self(), host);
		if (!MACH_PORT_VALID(kernel_task_port)) {
			return false;
		}
	}
	// Call task_info(TASK_DYLD_INFO) to get the kernel_all_image_info_addr struct address.
	if (kernel_all_image_info_addr == 0) {
		struct task_dyld_info info = {};
		mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
		kern_return_t kr = task_info(kernel_task_port, TASK_DYLD_INFO,
				(task_info_t) &info, &count);
		if (kr != KERN_SUCCESS) {
			ERROR("task_info(TASK_DYLD_INFO) failed: %d", kr);
			return false;
		}
		kernel_all_image_info_addr = info.all_image_info_addr;
	}
	// Grab the kernel base from kernel_all_image_info_addr.
	if (kernel_base_address == 0) {
		kernel_base_address = kernel_read64(kernel_all_image_info_addr +
				offsetof(struct kernel_all_image_info_addr, kernel_base_address));
	}
	// Grab kernproc from kernel_all_image_info_addr.
	if (kernproc == 0) {
		kernproc = kernel_read64(kernel_all_image_info_addr +
				offsetof(struct kernel_all_image_info_addr, kernproc));
	}
	// Anything else and we need parameters, so try to initialize those now.
	bool ok = kernel_parameters_init();
	if (!ok) {
		return false;
	}
	// Set the kernel slide.
	if (kernel_slide == 0) {
		kernel_slide = kernel_base_address - STATIC_ADDRESS(kernel_base);
	}
	// Get the (real) kernel task address.
	if (kernel_task == 0) {
		kernel_task = kernel_read64(kernproc + OFFSET(proc, task));
	}
	// Find the address of the current_task by walking the proc list. We need to start from
	// kernproc rather than just using the kernel task directly because kernel_task->bsd_info
	// does not point to kernproc.
	if (current_task == 0) {
		int pid = getpid();
		uint64_t current_proc = 0;
		uint64_t proc = kernproc;
		for (;;) {
			if (proc == 0 || proc == -1) {
				break;
			}
			// Check the PID to see if we've found the proc struct for this process.
			uint32_t proc_pid = kernel_read32(proc + OFFSET(proc, p_pid));
			if (proc_pid == pid) {
				current_proc = proc;
				break;
			}
			// If not, continue down the list. Since we started at the kernproc, we'll
			// traverse the prev pointers.
			proc = kernel_read64(proc + OFFSET(proc, p_list_prev));
		}
		// Check that we have found our process.
		if (current_proc == 0) {
			ERROR("Could not find proc strucut for the current process");
			return false;
		}
		// If we've found it, set current_task.
		current_task = kernel_read64(current_proc + OFFSET(proc, task));
	}
	return true;
}

bool
kernel_ipc_port_lookup(uint64_t task, mach_port_name_t port_name,
		uint64_t *ipc_entry, uint64_t *ipc_port, uint64_t *ip_kobject) {
	// Get the task's ipc_space.
	uint64_t itk_space = kernel_read64(task + OFFSET(task, itk_space));
	// Get the size of the table.
	uint32_t is_table_size = kernel_read32(itk_space + OFFSET(ipc_space, is_table_size));
	// Get the index of the port and check that it is in-bounds.
	uint32_t port_index = MACH_PORT_INDEX(port_name);
	if (port_index >= is_table_size) {
		return false;
	}
	// Get the space's is_table and compute the address of this port's entry.
	uint64_t is_table = kernel_read64(itk_space + OFFSET(ipc_space, is_table));
	uint64_t entry = is_table + port_index * SIZE(ipc_entry);
	if (ipc_entry != NULL) {
		*ipc_entry = entry;
	}
	if (ipc_port == NULL && ip_kobject == NULL) {
		goto done;
	}
	// Get the address of the ipc_port.
	uint64_t port = kernel_read64(entry + OFFSET(ipc_entry, ie_object));
	if (ipc_port != NULL) {
		*ipc_port = port;
	}
	if (ip_kobject == NULL) {
		goto done;
	}
	// Get the valueu of the ip_kobject field.
	*ip_kobject = kernel_read64(port + OFFSET(ipc_port, ip_kobject));
done:
	return true;
}

uint64_t
kernel_current_thread() {
	thread_t thread_self = mach_thread_self();
	uint64_t thread = 0;
	kernel_ipc_port_lookup(current_task, thread_self, NULL, NULL, &thread);
	mach_port_deallocate(mach_task_self(), thread_self);
	return thread;
}
