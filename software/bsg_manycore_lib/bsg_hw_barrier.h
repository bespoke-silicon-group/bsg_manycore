#ifndef BSG_HW_BARRIER_H
#define BSG_HW_BARRIER_H

inline void bsg_barsend()
{
  asm volatile (".word 0x1000000f");
}

inline void bsg_barrecv()
{
  asm volatile (".word 0x2000000f");
}


#endif
