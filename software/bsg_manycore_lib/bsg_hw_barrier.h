/**
 *    bsg_hw_barrier.h
 *
 *    HW Barrier Library
 */


#ifndef BSG_HW_BARRIER_H
#define BSG_HW_BARRIER_H


// Barrier Send
// Initiate the hw barrier by flipping the BAR PI register.
static inline void bsg_barsend()
{
  asm volatile (".word 0x1000000f");
}

// Barrier Receive
// Wait for the barrier in progress to complete (until Pi==Po).
static inline void bsg_barrecv()
{
  asm volatile (".word 0x2000000f");
}


#endif
