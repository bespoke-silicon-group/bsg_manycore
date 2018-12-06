#ifndef _BSG_MANYCORE_ASM_H
#define _BSG_MANYCORE_ASM_H

#define bsg_asm_remote_ptr(x,y,local_addr)         \
    ((REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS) \
      | ((y) << Y_CORD_SHIFTS )                    \
      | ((x) << X_CORD_SHIFTS )                    \
      | ( (local_addr)   )                         \
    )

#define bsg_asm_remote_store(x,y,local_addr,val) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);   \
    li t1, val;                                  \
    sw t1, 0x0(t0);

#define bsg_asm_remote_load(reg,x,y,local_addr) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);  \
    lw reg, 0x0(t0);

// print a register ("reg") in IO #x
#define bsg_asm_print_reg(x,reg)                  \
    li t0, bsg_asm_remote_ptr(x,bsg_tiles_Y,0x0); \
    sw reg, 0x0(t0);

// finish in IO #x
#define bsg_asm_finish(x) \
    bsg_asm_remote_store(x,bsg_tiles_Y,0xEAD0,0)

// fail in IO #x
#define bsg_asm_fail(x, value) \
    bsg_asm_remote_store(x,bsg_tiles_Y,0xEAD8,value)

#endif
