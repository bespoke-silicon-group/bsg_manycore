// A simple test to write to the full range of DMEM (4KB) and read it back.


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"
#define N 1024

// Root output selector: P/W/E/N/S (mesh) = 5, plus RW/RE (half-ruche X) = 7,
// plus RN/RS (Y ruche) = 9.
#if BARRIER_RUCHE_FACTOR_Y > 0
#define BAR_ROOT 9
#elif BARRIER_RUCHE_FACTOR_X > 0
#define BAR_ROOT 7
#else
#define BAR_ROOT 5
#endif

// initialize
.text
  bsg_asm_init_regfile


  // test1
  csrr t0, BARCFG_CSR_ADDR
  bne x0, t0, fail
  
  // test2
  li t0, ((BAR_ROOT << 16) | 1)
  csrrw x0, BARCFG_CSR_ADDR, t0
  csrr t1, BARCFG_CSR_ADDR
  bne t1, t0, fail

  // test3
  csrr x0, BARCFG_CSR_ADDR
  bsg_asm_barsend

  csrr t0, BAR_PI_CSR_ADDR
  li t1, 1
  bne t0, t1, fail

  csrr t0, BAR_PO_CSR_ADDR
  bne t0, t1, fail
  

  // test 4
  bsg_asm_barsend
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, x0, fail

  csrr t0, BAR_PO_CSR_ADDR
  bne t0, x0, fail

  // test5
  li t1, 1
  csrrw x0, BAR_PI_CSR_ADDR, t1
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, t1, fail

  csrrc x0, BAR_PI_CSR_ADDR, t1
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, x0, fail

  csrrs x0, BAR_PI_CSR_ADDR, t1
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, t1, fail

  csrrci x0, BAR_PI_CSR_ADDR, 1
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, x0, fail

  csrrsi x0, BAR_PI_CSR_ADDR, 1
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, t1, fail

  csrrwi x0, BAR_PI_CSR_ADDR, 0
  csrr t0, BAR_PI_CSR_ADDR
  bne t0, x0, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
