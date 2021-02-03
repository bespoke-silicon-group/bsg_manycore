# See LICENSE for license details.
# MBT modified for bsg_manycore

# bsg-tommy: we reserve the first two words of DMEM for interrupt handlers.
.section .dmem.interrupt,"a"
  .globl _interrupt_arr
_interrupt_arr:
  .space(8)

.section .crtbegin,"a"
  .globl _start
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

  # Enable FPU and clear fcsr.
  #
  # These are ignored by manycore hardware but might be
  # required by execution environments supporting 
  # exceptions (such as Spike).
  li t0, 0x00003000 # mstatus.FS
  csrs mstatus, t0 # enable FPU
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



  # initialize global pointer
  la gp, _gp

  la  tp, _bsg_data_end_addr + 63
  and tp, tp, -64

  # mbt: put stack at top of local memory
  # mbt fix for 4KB IMEM / 4KB DMEM
  la sp, _sp

#ifdef __bsg_newlib
  call dramfs_init
  call set_cmd_args
  lw a0, 0(sp)     # argc
  lw a1, -4(sp)    # argv
  li a2, 0         # envp = NULL
  call main
  tail exit
#else
  j main
#endif

2:
  # Should never this point
  j 2b
