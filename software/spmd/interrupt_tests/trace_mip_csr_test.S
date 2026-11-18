// A CSR access to mip must not discard the trace event from that instruction.
// Regression for bsg_manycore PR #779.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.section .text
.option norvc
.option norelax
.globl _start

_remote_interrupt:
  j fail
_trace_interrupt:
  j trace_handler

// Global interrupts stay disabled during setup. Enabling mstatus.MIE does
// not itself raise a trace event, so the tested CSR is the first traced op.
// s1: expected mepc; s2: case number; s4: old mip; s5: expected pending bits;
// s6: interrupt count; s7: value returned by the tested CSR; s0: trace mask.
.macro trace_csr operation, operand, pending=0, remote=0
  addi s2, s2, 1
  li s4, \pending
  li s5, \remote
  or s5, s5, s0
  csrw mip, s4
  csrw mie, s0
  la s1, 1f
  csrsi mstatus, 8
  \operation s7, mip, \operand
1:
  // On broken RTL this instruction is reached without an interrupt. It
  // disables MIE before another instruction can hide the lost trace event.
  csrci mstatus, 8
  bne s6, s2, fail
  bne s7, s4, fail
.endm

_start:
  bsg_asm_init_regfile
  csrw mstatus, zero
  csrw mie, zero
  csrw mip, zero
  li s0, 0x20000

  // Register-form controls, including clearing a pending remote bit and
  // attempting to clear trace while the hardware trace event has priority.
  trace_csr csrrw, zero, 0x10000, 0
  trace_csr csrrs, zero, 0x10000, 0x10000
  trace_csr csrrc, s0,   0x10000, 0x10000

  // Zero masks exercise the read-only CSRRSI/CSRRCI forms. Nonzero masks
  // exercise the other immediate path; neither mask reaches bits 17:16.
  // CSRRWI starts with no remote bit set, so these cases do not depend on
  // the separate, pre-existing handling of CSRRWI writes to upper bits.
  trace_csr csrrsi, 0
  trace_csr csrrci, 0
  trace_csr csrrwi, 0
  trace_csr csrrsi, 31
  trace_csr csrrci, 31
  trace_csr csrrwi, 31

  // An already-pending, masked remote interrupt must survive set/clear
  // immediate accesses. Remote interrupts remain disabled in mie.
  trace_csr csrrsi, 0,  0x10000, 0x10000
  trace_csr csrrci, 0,  0x10000, 0x10000
  trace_csr csrrsi, 31, 0x10000, 0x10000
  trace_csr csrrci, 31, 0x10000, 0x10000

  bsg_asm_finish_reg(IO_X_INDEX, s6)
pass_loop:
  j pass_loop

trace_handler:
  // A trace from a later instruction must not count as success.
  csrr t0, mepc
  bne t0, s1, fail
  csrr t0, mip
  bne t0, s5, fail
  addi s6, s6, 1
  csrw mie, zero
  csrw mip, zero
  // Clear MPIE as well as MIE: mret must return with tracing disabled,
  // leaving the checks and the next case's setup outside the traced region.
  csrw mstatus, zero
  mret

fail:
  csrw mstatus, zero
  bsg_asm_fail_reg(IO_X_INDEX, s2)
fail_loop:
  j fail_loop
