#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  li x1, 0
  li x2, 1
  li x3, 0x00001000
  sw x1, 0(x3)
  sw x2, 4(x3)
  li x3, 0x20001000 /* loading from the tile itself using remote load */
  li x6, 0x230c1000 /* loading from the distant tile which takes some cycles */
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  
  lw x30, 4(x3) /* this loads 1 */
  lw x10, 0(x6) /* these extra loads are here to force the wb of the second load of x30. */
  lw x11, 0(x6)
  lw x12, 0(x6)
  lw x30, 0(x3) /* this loads 0. this has to be done by stall_force_wb. */
  mul x5, x0, x0 /* this mul creates a long stall, which keeps the first load to x30 in the pipeline. */

  /* if everything went correctly, x30 should have 0.*/
  bne x0, x30, fail

  bsg_asm_finish(IO_X_INDEX, 0)


loop:
  beq x0, x0, loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

loop1:
  beq x0, x0, loop1
