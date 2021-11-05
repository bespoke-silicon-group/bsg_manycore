#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  li t0, 0
  li t1, 4096
  li t2, 0xbf83d70a // = -1.03
  fmv.s.x f0, t2

init_loop:
  flw f0, 0(t0)
  fmul.s f0, f0, f0
  addi t0, t0, 4
  bne t0, t1, init_loop

  nop
  nop
  nop
  bsg_asm_saif_start

flw f0, 0(x0)
flw f1, 4(x0)
flw f2, 8(x0)
flw f3, 12(x0)
flw f4, 16(x0)
flw f5, 20(x0)
flw f6, 24(x0)
flw f7, 28(x0)
flw f8, 32(x0)
flw f9, 36(x0)
flw f10, 40(x0)
flw f11, 44(x0)
flw f12, 48(x0)
flw f13, 52(x0)
flw f14, 56(x0)
flw f15, 60(x0)
flw f16, 64(x0)
flw f17, 68(x0)
flw f18, 72(x0)
flw f19, 76(x0)
flw f20, 80(x0)
flw f21, 84(x0)
flw f22, 88(x0)
flw f23, 92(x0)
flw f24, 96(x0)
flw f25, 100(x0)
flw f26, 104(x0)
flw f27, 108(x0)
flw f28, 112(x0)
flw f29, 116(x0)
flw f30, 120(x0)
flw f31, 124(x0)
flw f0, 128(x0)
flw f1, 132(x0)
flw f2, 136(x0)
flw f3, 140(x0)
flw f4, 144(x0)
flw f5, 148(x0)
flw f6, 152(x0)
flw f7, 156(x0)
flw f8, 160(x0)
flw f9, 164(x0)
flw f10, 168(x0)
flw f11, 172(x0)
flw f12, 176(x0)
flw f13, 180(x0)
flw f14, 184(x0)
flw f15, 188(x0)
flw f16, 192(x0)
flw f17, 196(x0)
flw f18, 200(x0)
flw f19, 204(x0)
flw f20, 208(x0)
flw f21, 212(x0)
flw f22, 216(x0)
flw f23, 220(x0)
flw f24, 224(x0)
flw f25, 228(x0)
flw f26, 232(x0)
flw f27, 236(x0)
flw f28, 240(x0)
flw f29, 244(x0)
flw f30, 248(x0)
flw f31, 252(x0)
flw f0, 256(x0)
flw f1, 260(x0)
flw f2, 264(x0)
flw f3, 268(x0)
flw f4, 272(x0)
flw f5, 276(x0)
flw f6, 280(x0)
flw f7, 284(x0)
flw f8, 288(x0)
flw f9, 292(x0)
flw f10, 296(x0)
flw f11, 300(x0)
flw f12, 304(x0)
flw f13, 308(x0)
flw f14, 312(x0)
flw f15, 316(x0)
flw f16, 320(x0)
flw f17, 324(x0)
flw f18, 328(x0)
flw f19, 332(x0)
flw f20, 336(x0)
flw f21, 340(x0)
flw f22, 344(x0)
flw f23, 348(x0)
flw f24, 352(x0)
flw f25, 356(x0)
flw f26, 360(x0)
flw f27, 364(x0)
flw f28, 368(x0)
flw f29, 372(x0)
flw f30, 376(x0)
flw f31, 380(x0)
flw f0, 384(x0)
flw f1, 388(x0)
flw f2, 392(x0)
flw f3, 396(x0)




  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
  
