/* 
  Description:
  A software-based PC profiler which builds a histogram of PCs encountered by the program

  Memory layout:
  DRAM --> 16MB (configurable) for maintaing a histogram for N tiles. 

  Registers used:
  The program being profiled is free to use any registers within if there are no other imposed constraints.
  The profiler uses the following registers - 
  t0 --> Base address of the histogram array (actual value stored in dmem[1])
  t1 --> Scratchpad (actual value stored in dmem[0])
*/

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Useful to control the amount of space required to simulate the use of the profiler.
// We want 16MB when running on actual hardware.
#ifndef HIST_SPACE
#define HIST_SPACE 16777216
#endif

#ifndef PROFILE
#define PROFILE 0
#endif

#if PROFILE > 0
/* 
  Data section:
  Defines a 2 element (8 byte) array to store the base pointer of the histogram array and for use by the interrupt handler to spill some registers
  dmem[0] = histogram base pointer, temporary storage
  dmem[1] = temporary storage
*/
.section .dmem.interrupt, "aw"
  _interrupt_arr: .space 8, 0x0

/*
  DRAM section:
  Defines a 16MB (array size is configurable) chunk in DRAM to store the histogram.

  Lingering question(s):
  1. Assigned space per PC (i.e bin capacity) as 32-bits. Is this enough, too much or too less?
  2. Base pointer in DRAM (for now it is mapped to start of DRAM) [Consider static assignment in linker]
*/
.section .dram, "aw"
.globl _histogram_arr
  _histogram_arr: .space HIST_SPACE, 0x0
#endif

/*
  Startup:
  This is very similar to the code in software/spmd/common/crt.S and adds only the interrupt service routine (ISR) and sets up the DMEM with the histogram base address. 
*/
.section .crtbegin
.globl _start

#if PROFILE > 0
/*
  Remote interrupt handler (should map to address 0)
*/
_remote_interrupt:
  j _remote_interrupt_handler

/*
  Trace interrupt handler (should map to address 4)
  Clears the pending trace interrupt bit in the MIP CSR and atomically increments the histogram bin count based on the MEPC CSR value

  The bin index in the histogram can be found using the following equation index = base ptr + EPC
  (Although EPC is 4-byte aligned, we are assigning 4 bytes per bin, so we don't need to do EPC >> 2)

  Lingering concerns:
  Since we are using the MEPC, we don't have the PC of the first instruction in the program. 
  (Probably does not matter because it's just 1 datapoint)
*/
_trace_interrupt:
  // Save a register to dmem[1]
  sw t0, 4(zero)

  // clear mip.trace
  li t0, 0x20000
  csrrc zero, mip, t0

  // load address of histogram array
  lw t0, 0(zero)
  // Store another register to dmem[0]
  sw t1, 0(zero)

  // read the mepc register
  csrr t1, mepc
  // find the correct index in the histogram array
  add t0, t0, t1

  // atomically increment the value at the computed index
  li t1, 1
  // We don't care about the result hence assigned to zero register
  amoadd.w.aq zero, t1, (t0)

  // remap t0 to histogram array base address
  csrr t1, mepc
  sub t0, t0, t1

  // Restore registers and store base ptr back to dmem[0]
  lw t1, 0(zero)
  sw t0, 0(zero)
  lw t0, 4(zero)

  mret

_remote_interrupt_handler:
  // Add code here when using in actual programs, for now these are turned off
  j fail
#endif

/*
  Start code
*/
_start:
  li  x1, 0
  // li  x2, 0
  li  x3, 0
  li  x4, 0
  li  x5, 0
  li  x6, 0
  li  x7, 0
  li  x8, 0
  li  x9, 0
  li  x10,0
  li  x11,0
  li  x12,0
  li  x13,0
  li  x14,0
  li  x15,0
  li  x16,0
  li  x17,0
  li  x18,0
  li  x19,0
  li  x20,0
  li  x21,0
  li  x22,0
  li  x23,0
  li  x24,0
  li  x25,0
  li  x26,0
  li  x27,0
  li  x28,0
  li  x29,0
  li  x30,0
  li  x31,0

  // Enable FPU and FCSR
  // These are ignored by manycore hardware but might be
  // required by execution environments supporting 
  // exceptions (such as Spike).
  li t0, 0x00003000
  csrs mstatus, t0
  fscsr x0
  li t0, 0

  fcvt.s.w f0, x0 
  fcvt.s.w f1, x0 
  fcvt.s.w f2, x0 
  fcvt.s.w f3, x0 
  fcvt.s.w f4, x0 
  fcvt.s.w f5, x0 
  fcvt.s.w f6, x0 
  fcvt.s.w f7, x0 
  fcvt.s.w f8, x0 
  fcvt.s.w f9, x0 
  fcvt.s.w f10,x0 
  fcvt.s.w f11,x0 
  fcvt.s.w f12,x0 
  fcvt.s.w f13,x0 
  fcvt.s.w f14,x0 
  fcvt.s.w f15,x0 
  fcvt.s.w f16,x0 
  fcvt.s.w f17,x0 
  fcvt.s.w f18,x0 
  fcvt.s.w f19,x0 
  fcvt.s.w f20,x0 
  fcvt.s.w f21,x0 
  fcvt.s.w f22,x0 
  fcvt.s.w f23,x0 
  fcvt.s.w f24,x0 
  fcvt.s.w f25,x0 
  fcvt.s.w f26,x0 
  fcvt.s.w f27,x0 
  fcvt.s.w f28,x0 
  fcvt.s.w f29,x0 
  fcvt.s.w f30,x0 
  fcvt.s.w f31,x0 

  // initialize global pointer
  la gp, _gp

  la  tp, _bsg_data_end_addr + 63
  and tp, tp, -64

  // mbt: put stack at top of local memory
  // mbt fix for 4KB IMEM / 4KB DMEM
  la sp, _sp

#if PROFILE > 0
  /*
    Profiler setup:
    This needs to be completed before the actual program starts if profiling needs to be enabled. 
    This snippet puts the base pointer for the histogram in dmem[0]
  */
  la t0, _histogram_arr
  sw t0, 0(zero)
  li t0, 0
#endif

#ifdef __bsg_newlib
  call dramfs_init
  call set_cmd_args
  lw a0, 0(sp)     // argc
  lw a1, -4(sp)    // argv
  li a2, 0         // envp = NULL
  call main
  tail exit
#else
  j main
#endif

2:
  // Should never reach this point
  j 2b

  // Must not come here
fail:
  j fail
