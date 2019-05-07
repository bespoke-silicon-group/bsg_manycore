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
  li sp, 4096*2-4

#ifdef __bsg_newlib
  call bsg_newlib_init
#endif

  lw a0, 0(sp)                    # argc
  addi a1, sp, __SIZEOF_POINTER__ # argv
  li a2, 0                        # envp = NULL
  call main
  tail exit

# Should never reach this
1:
  j 1b
