# See LICENSE for license details.
# MBT modified for bsg_manycore

.text
.globl _start
_start:
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
