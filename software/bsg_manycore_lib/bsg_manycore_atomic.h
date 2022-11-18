#ifndef _BSG_MANYCORE_ATOMIC_H
#define _BSG_MANYCORE_ATOMIC_H

inline int bsg_amoswap (volatile int* p, int val)
{
  int result;
  asm volatile ("amoswap.w %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_aq (volatile int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.aq %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_rl(volatile int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.rl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_aqrl(volatile int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.aqrl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}


inline int bsg_amoor (volatile int* p, int val)
{
  int result;
  asm volatile ("amoor.w %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_aq (volatile int* p, int val)
{
  int result;
  asm volatile ("amoor.w.aq %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_rl (volatile int* p, int val)
{
  int result;
  asm volatile ("amoor.w.rl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_aqrl (volatile int* p, int val)
{
  int result;
  asm volatile ("amoor.w.aqrl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoadd (volatile int* p, int val)
{
  int result;
  asm volatile ("amoadd.w %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoadd_aq (volatile int* p, int val)
{
  int result;
  asm volatile ("amoadd.w.aq %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoadd_rl (volatile int* p, int val)
{
  int result;
  asm volatile ("amoadd.w.rl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoadd_aqrl (volatile int* p, int val)
{
  int result;
  asm volatile ("amoadd.w.aqrl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

#endif
