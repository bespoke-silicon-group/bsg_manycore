#ifndef _BSG_MANYCORE_ASM_H
#define _BSG_MANYCORE_ASM_H

/*******************************************************
 * Some useful macros for manycore assembly programming
 * Only use temporary registers (t0-6) here.
 *******************************************************/

// Loads and stores

#define bsg_asm_remote_ptr(x,y,local_addr)         \
    ((1 << REMOTE_PREFIX_SHIFT) \
      | ((y) << REMOTE_Y_CORD_SHIFT )                    \
      | ((x) << REMOTE_X_CORD_SHIFT )                    \
      | ( (local_addr)   )                         \
    )

#define bsg_asm_global_ptr(x,y,local_addr)  ( (1 << GLOBAL_PREFIX_SHIFT) \
                                                               | ((y) << GLOBAL_Y_CORD_SHIFT )                     \
                                                               | ((x) << GLOBAL_X_CORD_SHIFT )                     \
                                                               | ( local_addr          )                     \
                                            )                                               \

#define bsg_asm_remote_store(x,y,local_addr,val) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);   \
    li t1, val;                                  \
    sw t1, 0x0(t0);

#define bsg_asm_global_store(x,y,local_addr,val) \
    li t0, bsg_asm_global_ptr(x,y,local_addr);   \
    li t1, val;                                  \
    sw t1, 0x0(t0);

#define bsg_asm_remote_store_reg(x,y,local_addr,reg) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);       \
    sw reg, 0x0(t0);

#define bsg_asm_global_store_reg(x,y,local_addr,reg) \
    li t0, bsg_asm_global_ptr(x,y,local_addr);       \
    sw reg, 0x0(t0);

#define bsg_asm_local_store(local_addr,val) \
    li t0, local_addr;                      \
    li t1, val;                             \
    sw t1, 0x0(t0);

#define bsg_asm_local_store_reg(local_addr,reg) \
    li t0, local_addr;                          \
    sw reg, 0x0(t0);

#define bsg_asm_remote_load(reg,x,y,local_addr) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);  \
    lw reg, 0x0(t0);

#define bsg_asm_local_load(reg,local_addr) \
    li t0, local_addr;                     \
    lw reg, 0x0(t0);

// Remote Interrupt address (global EVA)
#define bsg_global_remote_interrupt_ptr(x,y) bsg_asm_global_ptr(x,y,0xfffc)
// Remote Interrupt address (tile-group EVA)
#define bsg_tile_group_remote_interrupt_ptr(x,y) bsg_asm_remote_ptr(x,y,0xfffc)


// IO macros

// print value in IO #x
#define bsg_asm_print(x,val)                      \
    li t0, bsg_asm_global_ptr(x, IO_Y_INDEX,0x0); \
    li t1, val;                                   \
    sw t1, 0x0(t0);

// print a register ("reg") in IO #x
#define bsg_asm_print_reg(x,reg)                  \
    li t0, bsg_asm_global_ptr(x, IO_Y_INDEX,0x0); \
    sw reg, 0x0(t0);

// finish with value in IO #x
#define bsg_asm_finish(x,val) \
    bsg_asm_global_store(x, IO_Y_INDEX,0xEAD0,val)

// print out time
#define bsg_asm_print_time(x,val) \
    bsg_asm_global_store(x, IO_Y_INDEX,0xEAD4,val)


// finish with value in a reg in IO #x
#define bsg_asm_finish_reg(x,reg) \
    bsg_asm_global_store_reg(x,IO_Y_INDEX,0xEAD0,reg)

// fail with value in IO #x
#define bsg_asm_fail(x, value) \
    bsg_asm_global_store(x, IO_Y_INDEX ,0xEAD8,value)

// fail with value in a reg in IO #x
#define bsg_asm_fail_reg(x,reg) \
    bsg_asm_global_store_reg(x, IO_Y_INDEX ,0xEAD8,reg)

// saif
#define bsg_asm_saif_start \
  bsg_asm_global_store(IO_X_INDEX, IO_Y_INDEX,0xFFF0,0)

#define bsg_asm_saif_end \
  bsg_asm_global_store(IO_X_INDEX, IO_Y_INDEX,0xFFF4,0)


// Branch

// branch immediate
#define bi(op,reg,val,dest) \
    li t0, val;             \
    op reg,t0,dest;

// start code
#define bsg_asm_init_regfile  \
    li x1, 0;                 \
    li x2, 4096;              \
    li x3, 0;                 \
    li x4, 0;                 \
    li x5, 0;                 \
    li x6, 0;                 \
    li x7, 0;                 \
    li x8, 0;                 \
    li x9, 0;                 \
    li x10,0;                 \
    li x11,0;                 \
    li x12,0;                 \
    li x13,0;                 \
    li x14,0;                 \
    li x15,0;                 \
    li x16,0;                 \
    li x17,0;                 \
    li x18,0;                 \
    li x19,0;                 \
    li x20,0;                 \
    li x21,0;                 \
    li x22,0;                 \
    li x23,0;                 \
    li x24,0;                 \
    li x25,0;                 \
    li x26,0;                 \
    li x27,0;                 \
    li x28,0;                 \
    li x29,0;                 \
    li x30,0;                 \
    li x31,0;                 \
                              \
    fcvt.s.w f0, x0;          \
    fcvt.s.w f1, x0;          \
    fcvt.s.w f2, x0;          \
    fcvt.s.w f3, x0;          \
    fcvt.s.w f4, x0;          \
    fcvt.s.w f5, x0;          \
    fcvt.s.w f6, x0;          \
    fcvt.s.w f7, x0;          \
    fcvt.s.w f8, x0;          \
    fcvt.s.w f9, x0;          \
    fcvt.s.w f10,x0;          \
    fcvt.s.w f11,x0;          \
    fcvt.s.w f12,x0;          \
    fcvt.s.w f13,x0;          \
    fcvt.s.w f14,x0;          \
    fcvt.s.w f15,x0;          \
    fcvt.s.w f16,x0;          \
    fcvt.s.w f17,x0;          \
    fcvt.s.w f18,x0;          \
    fcvt.s.w f19,x0;          \
    fcvt.s.w f20,x0;          \
    fcvt.s.w f21,x0;          \
    fcvt.s.w f22,x0;          \
    fcvt.s.w f23,x0;          \
    fcvt.s.w f24,x0;          \
    fcvt.s.w f25,x0;          \
    fcvt.s.w f26,x0;          \
    fcvt.s.w f27,x0;          \
    fcvt.s.w f28,x0;          \
    fcvt.s.w f29,x0;          \
    fcvt.s.w f30,x0;          \
    fcvt.s.w f31,x0;       
    
#endif
