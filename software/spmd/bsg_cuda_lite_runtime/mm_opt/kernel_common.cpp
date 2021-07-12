#include <kernel_common.hpp>
#include <string.h>
#include <stdint.h>

// common reduction buffer
void* g_reduction_buffer;

// common barrier for all kernels
#ifdef HB_EMUL
bsg_barrier g_barrier;
#else
bsg_barrier<bsg_tiles_X, bsg_tiles_Y> g_barrier;
#endif // HB_EMUL

// This is just Newlib's memcpy with bsg_attr_remote annotations
bsg_attr_remote void* hb_memcpy(bsg_attr_remote void* bsg_attr_noalias aa,
               const bsg_attr_remote void* bsg_attr_noalias bb,
               size_t n) {
  #define unlikely(X) __builtin_expect (!!(X), 0)

  #define BODY(a, b, t) { \
    t tt = *b; \
    a++, b++; \
    *(a - 1) = tt; \
  }

  bsg_attr_remote char *a = (bsg_attr_remote char *)aa;
  const bsg_attr_remote char *b = (const bsg_attr_remote char *)bb;
  bsg_attr_remote char *end = a + n;
  uintptr_t msk = sizeof (long) - 1;
  if (unlikely ((((uintptr_t)a & msk) != ((uintptr_t)b & msk))
           || n < sizeof (long)))
    {
small:
      if (__builtin_expect (a < end, 1))
    while (a < end)
      BODY (a, b, char);
      return aa;
    }

  if (unlikely (((uintptr_t)a & msk) != 0))
    while ((uintptr_t)a & msk)
      BODY (a, b, char);

  bsg_attr_remote long *la = (bsg_attr_remote long *)a;
  const bsg_attr_remote long *lb = (const bsg_attr_remote long *)b;
  bsg_attr_remote long *lend = (bsg_attr_remote long *)((uintptr_t)end & ~msk);

  if (unlikely (la < (lend - 8)))
    {
      while (la < (lend - 8))
    {
      long b0 = *lb++;
      long b1 = *lb++;
      long b2 = *lb++;
      long b3 = *lb++;
      long b4 = *lb++;
      long b5 = *lb++;
      long b6 = *lb++;
      long b7 = *lb++;
      long b8 = *lb++;
      *la++ = b0;
      *la++ = b1;
      *la++ = b2;
      *la++ = b3;
      *la++ = b4;
      *la++ = b5;
      *la++ = b6;
      *la++ = b7;
      *la++ = b8;
    }
    }

  while (la < lend)
    BODY (la, lb, long);

  a = (bsg_attr_remote char *)la;
  b = (const bsg_attr_remote char *)lb;
  if (unlikely (a < end))
    goto small;
  return aa;
}
