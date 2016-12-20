# See LICENSE for license details.
# MBT modified for bsg_manycore

#include "encoding.h"

#ifdef __riscv64
# define LREG ld
# define SREG sd
# define REGBYTES 8
#else
# define LREG lw
# define SREG sw
# define REGBYTES 4
#endif

#ifdef __bsg_exception
  .text
  .align 6
user_trap_entry:
   li a5,0
   csrw mtohost,a5
   j .

  .align 6
supervisor_trap_entry:
   li a5,1
   csrw mtohost,a5
   j .

  .align 6
hypervisor_trap_entry:
   li a5,2
   csrw mtohost,a5
   j .

  .align 6
machine_trap_entry:
   li a5,3
   csrw mtohost,a5
   j .

#endif


.align 6
  .globl _start
_start:
  li  x1, 0
  li  x2, 0
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

  li t0, MSTATUS_PRV1; csrc mstatus, t0    # run tests in user mode
  li t0, MSTATUS_IE1;  csrs mstatus, t0    # enable interrupts in user mode
  li t0, MSTATUS_FS;   csrs mstatus, t0    # enable FPU
  li t0, MSTATUS_XS;   csrs mstatus, t0    # enable accelerator

#ifdef __riscv64
  csrr t0, mcpuid
  # make sure processor supports RV64 if this was compiled for RV64
  bltz t0, 1f
  li a0, 1234
  j tohost_exit
1:
#endif

  csrr t0, mstatus
  li t1, MSTATUS_XS
  and t1, t0, t1

  # mbt comment out
  # sw t1, have_vec, t2

  ## if that didn't stick, we don't have a FPU, so don't initialize it
  li t1, MSTATUS_FS
  and t1, t0, t1
  beqz t1, 1f

#ifdef __riscv_hard_float
  fssr    x0
  fmv.s.x f0, x0
  fmv.s.x f1, x0
  fmv.s.x f2, x0
  fmv.s.x f3, x0
  fmv.s.x f4, x0
  fmv.s.x f5, x0
  fmv.s.x f6, x0
  fmv.s.x f7, x0
  fmv.s.x f8, x0
  fmv.s.x f9, x0
  fmv.s.x f10,x0
  fmv.s.x f11,x0
  fmv.s.x f12,x0
  fmv.s.x f13,x0
  fmv.s.x f14,x0
  fmv.s.x f15,x0
  fmv.s.x f16,x0
  fmv.s.x f17,x0
  fmv.s.x f18,x0
  fmv.s.x f19,x0
  fmv.s.x f20,x0
  fmv.s.x f21,x0
  fmv.s.x f22,x0
  fmv.s.x f23,x0
  fmv.s.x f24,x0
  fmv.s.x f25,x0
  fmv.s.x f26,x0
  fmv.s.x f27,x0
  fmv.s.x f28,x0
  fmv.s.x f29,x0
  fmv.s.x f30,x0
  fmv.s.x f31,x0
#endif

1:

  # initialize global pointer
  la gp, _gp

  la  tp, _end + 63
  and tp, tp, -64

  # get core id
  #csrr a0, mhartid
  # for now, assume only 1 core
  #li a1, 1
  #1:bgeu a0, a1, 1b

  # mbt: put stack at top of local memory
  # mbt fix for 4KB IMEM / 4KB DMEM
  li sp, 4096*2-4
  #la t0, main
  #csrw mepc, t0
  j main
  eret

trap_entry:

.section ".tdata.begin"
.globl _tdata_begin
_tdata_begin:

.section ".tdata.end"
.globl _tdata_end
_tdata_end:

.section ".tbss.end"
.globl _tbss_end
_tbss_end:
