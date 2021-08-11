/* 
  Description:
  A software-based PC profiler which builds a histogram of PCs encountered by the program

  Memory layout:
  DRAM --> 16MB (configurable) for maintaing a histogram for N tiles. 

  Registers used:
  The program being profiled is free to use any registers within if there are no other imposed constraints.
  The profiler uses the following registers - 
  t0 --> Base address of the histogram array (actual value stored in dmem[1])
  t1 --> Scratchpad (actual value stored in dmem[2])
*/

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Useful to control the amount of space required to simulate the use of the profiler.
// We want 16MB when running on actual hardware.
#ifndef HIST_SPACE
#define HIST_SPACE 16777216
#endif


/* 
  Data section:
  Defines a 2 element (8 byte) array to store the base pointer of the histogram array and for use by the interrupt handler to spill some registers
  dmem[0] = temporary storage
  dmem[1] = temporary storage
*/
//.section .dmem.interrupt, "aw"
//  _interrupt_arr: .space 12, 0x0

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


/*
  Remote interrupt handler (should map to address 0)
*/
.section .text.interrupt, "a"
_remote_interrupt:
  j _remote_interrupt_handler

/*
  Trace interrupt handler (should map to address 4)
  Clears the pending trace interrupt bit in the MIP CSR and atomically increments the histogram bin count based on the MEPC CSR value

  The bin index in the histogram can be found using the following equation index = base ptr + EPC
  (Although EPC is 4-byte aligned, we are assigning 4 bytes per bin, so we don't need to do EPC >> 2)

  Since we are using the MEPC, we don't have the PC of the first instruction in the program (this is usually the call to the main function for non-inlined functions)
*/

_trace_interrupt:
  // Save a register to dmem[1]
  sw t0, 0(zero)
  sw t1, 4(zero)

  // clear mip.trace
  li t0, 0x20000
  csrrc zero, mip, t0

  // load address of histogram array
  la t0, _histogram_arr

  // read the mepc register
  csrr t1, mepc
  // find the correct index in the histogram array
  add t0, t0, t1

  // atomically increment the value at the computed index
  li t1, 1
  // We don't care about the result hence assigned to zero register
  amoadd.w zero, t1, (t0)

  // Restore registers and store base ptr back to dmem[0]
  lw t0, 0(zero)
  lw t1, 4(zero)

  mret

_remote_interrupt_handler:
  // Add code here when using in actual programs, for now these are turned off
  bsg_asm_fail(IO_X_INDEX, 0)
