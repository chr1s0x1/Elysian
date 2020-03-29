//
//  pac_bypass.h
//  Brandon Azad
//
#ifndef OOB_TIMESTAMP__PAC_BYPASS__H_
#define OOB_TIMESTAMP__PAC_BYPASS__H_

#include <stdbool.h>
#include <stdint.h>

// ---- Kernel thread state for arm64e ------------------------------------------------------------

// See osfmk/mach/arm/thread_status.h.

#define ARM_SAVED_STATE64	21

struct arm64e_saved_state {
	uint32_t flavor;
	uint32_t count;
	uint64_t x[29];
	uint64_t fp;
	uint64_t lr;
	uint64_t sp;
	uint64_t pc;
	uint32_t cpsr;
	uint32_t reserved;
	uint64_t far;
	uint32_t esr;
	uint32_t exception;
	uint64_t pac_signature;
};

struct arm64e_context {
	uint32_t flavor;
	uint32_t count;
	uint64_t x[29];
	uint64_t fp;
	uint64_t lr;
	uint64_t sp;
	uint64_t pc;
	uint32_t cpsr;
	uint32_t reserved;
	uint64_t far;
	uint32_t esr;
	uint32_t exception;
	uint64_t pac_signature;
	uint32_t neon_flavor;
	uint32_t neon_count;
	__int128 q[32];
	uint32_t fpsr;
	uint32_t fpcr;
};

// ---- PAC bypass --------------------------------------------------------------------------------

/*
 * pac_bypass__sign_thread_state
 *
 * Description:
 * 	Bypass PAC on arm64e devices in order to produce an ml_sign_thread_state() signature on the
 * 	specified thread state.
 *
 * 	This function should only be called once.
 */
void pac_bypass__sign_thread_state(uint64_t state,
		uint64_t pc, uint32_t cpsr, uint64_t lr,
		uint64_t x16, uint64_t x17);

#endif
