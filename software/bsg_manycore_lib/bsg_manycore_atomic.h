#ifndef _BSG_MANYCORE_ATOMIC_H
#define _BSG_MANYCORE_ATOMIC_H

inline int bsg_amoswap (int* p, int val)
{
  int result;
  asm volatile ("amoswap.w %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_aq (int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.aq %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_rl(int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.rl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoswap_aqrl(int* p, int val)
{
  int result;
  asm volatile ("amoswap.w.aqrl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}


inline int bsg_amoor (int* p, int val)
{
  int result;
  asm volatile ("amoor.w %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_aq (int* p, int val)
{
  int result;
  asm volatile ("amoor.w.aq %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_rl (int* p, int val)
{
  int result;
  asm volatile ("amoor.w.rl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}

inline int bsg_amoor_aqrl (int* p, int val)
{
  int result;
  asm volatile ("amoor.w.aqrl %[result], %[val], 0(%[p])" \
                : [result] "=r" (result) \
                : [p] "r" (p), [val] "r" (val));
  return result;
}


#endif
