#ifndef _BSG_MANYCORE_ASM_H
#define _BSG_MANYCORE_ASM_H

/*******************************************************
 * Some useful macros for manycore assembly programming
 * Only use temporary registers (t0-6) here.
 *******************************************************/

// Loads and stores

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

#define bsg_asm_remote_store_reg(x,y,local_addr,reg) \
    li t0, bsg_asm_remote_ptr(x,y,local_addr);       \
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


// IO macros

// print value in IO #x
#define bsg_asm_print(x,val)                      \
    li t0, bsg_asm_remote_ptr(x,bsg_tiles_Y,0x0); \
    li t1, val;                                   \
    sw t1, 0x0(t0);

// print a register ("reg") in IO #x
#define bsg_asm_print_reg(x,reg)                  \
    li t0, bsg_asm_remote_ptr(x,bsg_tiles_Y,0x0); \
    sw reg, 0x0(t0);

// finish with value in IO #x
#define bsg_asm_finish(x,val) \
    bsg_asm_remote_store(x,bsg_tiles_Y,0xEAD0,val)

// finish with value in a reg in IO #x
#define bsg_asm_finish_reg(x,reg) \
    bsg_asm_remote_store_reg(x,bsg_tiles_Y,0xEAD0,reg)

// fail with value in IO #x
#define bsg_asm_fail(x, value) \
    bsg_asm_remote_store(x,bsg_tiles_Y,0xEAD8,value)

// fail with value in a reg in IO #x
#define bsg_asm_fail_reg(x,reg) \
    bsg_asm_remote_store_reg(x,bsg_tiles_Y,0xEAD8,reg)


// Branch

// branch immediate
#define bi(op,reg,val,dest) \
    li t0, val;             \
    op reg,t0,dest;

#endif
