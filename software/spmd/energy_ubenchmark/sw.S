#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  li x1, 874085
  li x2, 122638
  li x3, 565442
  li x4, 492195
  li x5, -480744
  li x6, -647448
  li x7, -480899
  li x8, -707317
  li x9, -954797
  li x10, -95630
  li x11, 74589
  li x12, 322742
  li x13, 144789
  li x14, 116354
  li x15, 680491
  li x16, 173234
  li x17, -64461
  li x18, -160759
  li x19, 499978
  li x20, -727826
  li x21, -437681
  li x22, -17313
  li x23, 351009
  li x24, 359178
  li x25, -123824
  li x26, -833894
  li x27, -259992
  li x28, 183407
  li x29, 536807
  li x30, -607249
  li x31, -872841
  
  nop
  nop
  nop
  bsg_asm_saif_start
  sw x26, 420(x0)
  sw x4, 228(x0)
  sw x22, 40(x0)
  sw x14, 404(x0)
  sw x17, 212(x0)
  sw x22, 312(x0)
  sw x14, 168(x0)
  sw x25, 496(x0)
  sw x10, 336(x0)
  sw x10, 208(x0)
  sw x3, 112(x0)
  sw x19, 252(x0)
  sw x8, 424(x0)
  sw x6, 272(x0)
  sw x19, 140(x0)
  sw x8, 432(x0)
  sw x10, 364(x0)
  sw x9, 420(x0)
  sw x15, 312(x0)
  sw x1, 448(x0)
  sw x10, 260(x0)
  sw x9, 264(x0)
  sw x16, 92(x0)
  sw x22, 184(x0)
  sw x6, 356(x0)
  sw x3, 420(x0)
  sw x12, 284(x0)
  sw x7, 88(x0)
  sw x2, 416(x0)
  sw x2, 416(x0)
  sw x12, 292(x0)
  sw x21, 16(x0)
  sw x13, 328(x0)
  sw x9, 300(x0)
  sw x16, 432(x0)
  sw x1, 396(x0)
  sw x25, 240(x0)
  sw x30, 288(x0)
  sw x30, 372(x0)
  sw x15, 300(x0)
  sw x16, 324(x0)
  sw x20, 0(x0)
  sw x25, 88(x0)
  sw x3, 308(x0)
  sw x2, 220(x0)
  sw x9, 288(x0)
  sw x22, 412(x0)
  sw x27, 456(x0)
  sw x13, 228(x0)
  sw x7, 440(x0)
  sw x9, 44(x0)
  sw x16, 416(x0)
  sw x10, 204(x0)
  sw x25, 500(x0)
  sw x27, 4(x0)
  sw x7, 304(x0)
  sw x15, 276(x0)
  sw x20, 72(x0)
  sw x9, 264(x0)
  sw x13, 216(x0)
  sw x17, 368(x0)
  sw x10, 100(x0)
  sw x6, 160(x0)
  sw x29, 172(x0)
  sw x13, 404(x0)
  sw x18, 292(x0)
  sw x24, 284(x0)
  sw x30, 392(x0)
  sw x16, 408(x0)
  sw x22, 236(x0)
  sw x23, 364(x0)
  sw x25, 200(x0)
  sw x3, 36(x0)
  sw x24, 80(x0)
  sw x24, 72(x0)
  sw x26, 32(x0)
  sw x1, 220(x0)
  sw x2, 424(x0)
  sw x22, 28(x0)
  sw x8, 180(x0)
  sw x17, 116(x0)
  sw x31, 300(x0)
  sw x4, 104(x0)
  sw x10, 336(x0)
  sw x16, 64(x0)
  sw x10, 456(x0)
  sw x20, 352(x0)
  sw x31, 112(x0)
  sw x9, 300(x0)
  sw x20, 312(x0)
  sw x5, 440(x0)
  sw x19, 196(x0)
  sw x22, 212(x0)
  sw x16, 44(x0)
  sw x23, 484(x0)
  sw x20, 420(x0)
  sw x21, 412(x0)
  sw x27, 68(x0)
  sw x5, 84(x0)
  sw x27, 236(x0)
  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
