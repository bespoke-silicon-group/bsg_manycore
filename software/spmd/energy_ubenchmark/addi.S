#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile

  li x1 ,0x57fcd102
  li x2 ,0xfff83492
  li x3 ,0x00031587
  li x4 ,0x0015ff7f
  li x5 ,0x011fe39c
  li x6 ,0x03295e93
  li x7 ,0x312896f8
  li x8 ,0x75455f11
  li x9 ,0x2dee2161
  li x10,0x7138813b
  li x11,0x000b5c8b
  li x12,0x011edcb2
  li x13,0x144144dd
  li x14,0xcfe72316
  li x15,0x7552b181

  // saif start
  bsg_asm_saif_start

  addi x24, x8, -2
  addi x28, x2, 499
  addi x19, x2, -306
  addi x20, x15, -240
  addi x20, x8, 350
  addi x20, x12, -486
  addi x21, x11, -218
  addi x17, x8, 347
  addi x22, x9, -158
  addi x29, x10, 37
  addi x16, x12, 428
  addi x26, x0, -279
  addi x31, x7, 80
  addi x23, x2, 224
  addi x26, x6, -19
  addi x26, x3, 146
  addi x26, x13, -393
  addi x16, x0, 9
  addi x31, x2, -251
  addi x21, x0, -445
  addi x31, x6, 108
  addi x30, x4, -429
  addi x28, x0, -449
  addi x31, x7, 245
  addi x23, x11, 327
  addi x26, x11, -341
  addi x23, x13, 394
  addi x28, x5, -124
  addi x21, x2, 443
  addi x21, x4, 122
  addi x25, x12, 336
  addi x25, x13, 19
  addi x27, x9, 287
  addi x31, x6, -295
  addi x27, x9, 392
  addi x17, x14, -298
  addi x17, x13, -172
  addi x29, x0, -449
  addi x18, x7, 307
  addi x30, x9, 349
  addi x25, x4, -281
  addi x20, x3, 8
  addi x22, x6, -204
  addi x31, x9, -347
  addi x16, x10, -371
  addi x26, x15, 430
  addi x25, x3, 166
  addi x18, x15, 474
  addi x19, x7, 242
  addi x20, x12, -217
  addi x30, x5, 381
  addi x21, x1, 424
  addi x23, x13, 431
  addi x31, x15, 498
  addi x16, x4, -174
  addi x17, x10, -127
  addi x29, x2, -390
  addi x27, x15, 302
  addi x19, x4, 376
  addi x25, x10, -58
  addi x27, x11, -82
  addi x18, x5, -126
  addi x26, x1, -339
  addi x25, x6, -277
  addi x16, x2, 119
  addi x25, x13, -383
  addi x19, x9, 150
  addi x22, x14, 137
  addi x28, x13, 406
  addi x17, x15, -271
  addi x16, x11, -188
  addi x22, x4, 197
  addi x29, x15, 357
  addi x29, x15, -281
  addi x28, x13, 52
  addi x18, x8, -500
  addi x27, x0, -258
  addi x18, x15, 160
  addi x17, x1, 223
  addi x21, x9, -135
  addi x24, x11, -149
  addi x16, x14, -150
  addi x26, x13, -272
  addi x18, x14, 429
  addi x27, x1, 497
  addi x20, x11, -177
  addi x20, x11, 36
  addi x19, x7, 376
  addi x21, x10, 249
  addi x20, x14, 213
  addi x26, x5, 393
  addi x17, x10, -483
  addi x25, x5, 7
  addi x24, x2, 119
  addi x26, x1, 381
  addi x27, x12, 395
  addi x20, x7, 148
  addi x27, x5, -133
  addi x20, x3, 179
  addi x30, x8, 200

  // saif end
  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
