//
//  kernel_call.h
//  Brandon Azad
//

#ifndef OOB_TIMESTAMP__KERNEL_CALL__H_
#define OOB_TIMESTAMP__KERNEL_CALL__H_

#include <stdbool.h>
#include <stdint.h>

/*
 * kernel_call_init
 *
 * Description:
 * 	Initialize the kernel function calling capability.
 */
bool kernel_call_init(void);

/*
 * kernel_call_8
 *
 * Description:
 * 	Call a kernel function with up to 8 64-bit integral arguments and return the 64-bit
 * 	integral return value.
 *
 * 	The macro version of this function will accept fewer than 8 arguments and uses zero for the
 * 	unspecified values.
 */
uint64_t kernel_call_8(uint64_t function,
		uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3,
		uint64_t x4, uint64_t x5, uint64_t x6, uint64_t x7);

/*
 * MACRO kernel_call_8
 *
 * Description:
 * 	A wrapper around the function kernel_call_8 that passes zero for unspecified arguments.
 */
#define kernel_call_8(_function, ...)	\
	kernel_call_8m1(_function, ##__VA_ARGS__, 0, 0, 0, 0, 0, 0, 0, 0, ~)
#define kernel_call_8m1(_function, _x0, _x1, _x2, _x3, _x4, _x5, _x6, _x7, ...)	\
	kernel_call_8(_function, _x0, _x1, _x2, _x3, _x4, _x5, _x6, _x7)

#endif
