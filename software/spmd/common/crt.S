# See LICENSE for license details.
# MBT modified for bsg_manycore

  .globl _start
_start:
  li  x1, 0
  # li  x2, 0; stack pointer
  # li  x3, 0; global pointer
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


  # initialize global pointer
  la gp, _gp

  la  tp, _bsg_data_end_addr + 63
  and tp, tp, -64

  # mbt: put stack at top of local memory
  # mbt fix for 4KB IMEM / 4KB DMEM
  la sp, _sp

#ifdef __bsg_newlib
  call bsg_newlib_init
  call set_cmd_args
  lw a0, 0(sp)     # argc
  lw a1, -4(sp)    # argv
  li a2, 0         # envp = NULL
  call main
  tail exit
#else
  j main
#endif

# Should never reach this
1:
  j 1b
