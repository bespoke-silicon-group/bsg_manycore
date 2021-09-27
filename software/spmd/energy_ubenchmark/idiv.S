#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  li x1, 82
  li x2, -118282
  li x3, 21992
  li x4, 371
  li x5, 319282
  li x6, -568955
  li x7, 99209
  li x8, 4
  li x9, -384387
  li x10, -697988
  li x11, 8726
  li x12, 419706
  li x13, 20
  li x14, -535533
  li x15, 1284712

  // saif start
  bsg_asm_saif_start

  div x17, x9, x7
  div x17, x9, x11
  div x27, x6, x11
  div x29, x12, x6
  div x18, x15, x8
  div x18, x4, x2
  div x24, x4, x1
  div x17, x8, x12
  div x19, x8, x12
  div x26, x6, x13
  div x24, x6, x8
  div x24, x7, x11
  div x19, x6, x11
  div x20, x10, x12
  div x19, x6, x8
  div x17, x14, x6
  div x21, x13, x7
  div x23, x15, x12
  div x20, x7, x1
  div x23, x12, x12
  div x24, x8, x14
  div x27, x10, x11
  div x25, x12, x5
  div x16, x4, x14
  div x20, x1, x14
  div x23, x6, x2
  div x27, x3, x12
  div x31, x8, x14
  div x26, x1, x3
  div x27, x13, x15
  div x26, x4, x2
  div x23, x15, x4
  div x20, x3, x5
  div x27, x5, x3
  div x29, x13, x8
  div x31, x9, x4
  div x27, x3, x5
  div x29, x14, x13
  div x17, x3, x4
  div x30, x8, x7
  div x30, x12, x1
  div x18, x14, x11
  div x18, x8, x3
  div x20, x13, x11
  div x22, x14, x12
  div x18, x4, x13
  div x23, x5, x5
  div x27, x1, x1
  div x20, x13, x11
  div x18, x12, x6
  div x22, x4, x9
  div x23, x13, x12
  div x23, x7, x8
  div x17, x4, x9
  div x17, x9, x6
  div x26, x10, x14
  div x20, x13, x11
  div x28, x2, x9
  div x24, x9, x1
  div x27, x8, x14
  div x27, x9, x4
  div x18, x4, x6
  div x31, x15, x1
  div x28, x10, x1
  div x24, x14, x6
  div x16, x11, x6
  div x19, x3, x6
  div x20, x9, x14
  div x22, x14, x15
  div x20, x10, x8
  div x25, x10, x6
  div x20, x13, x13
  div x28, x13, x10
  div x19, x15, x5
  div x21, x8, x8
  div x27, x8, x2
  div x26, x12, x5
  div x31, x14, x3
  div x21, x1, x6
  div x16, x8, x1
  div x17, x8, x13
  div x16, x10, x8
  div x17, x8, x10
  div x21, x9, x2
  div x17, x11, x8
  div x23, x11, x10
  div x19, x3, x11
  div x21, x3, x4
  div x29, x15, x9
  div x18, x7, x10
  div x16, x9, x15
  div x24, x2, x15
  div x16, x9, x3
  div x28, x4, x15
  div x22, x10, x4
  div x26, x8, x15
  div x22, x15, x2
  div x25, x6, x2
  div x27, x5, x2
  div x20, x3, x9


  // saif end
  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
