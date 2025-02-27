#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 536870912
//#define N 32768
#define VCACHE_LINE_WORDS 8


#define cbo_inval_block(addr) ({ \
  __asm__ __volatile__ (".insn i 0x0f, 0b010, x0, %0, 0x0" : : "r" (addr)); \
  })

#define cbo_clean_block(addr) ({ \
  __asm__ __volatile__ (".insn i 0x0f, 0b010, x0, %0, 0x1" : : "r" (addr)); \
  })

#define cbo_flush_block(addr) ({ \
  __asm__ __volatile__ (".insn i 0x0f, 0b010, x0, %0, 0x2" : : "r" (addr)); \
  })

#define cbo_taglv(ret, addr) ({ \
  __asm__ __volatile__ (".insn i 0x0f, 0b010, %0, %1, 0x3" : "=r" (ret) : "r" (addr)); \
  })

// 0(rs1) <- rs2
#define uncached_write(rs1, rs2) ({ \
  __asm__ __volatile__ (".insn r 0b0100011, 0b111, 0x0, x0, %0, %1" : : "r" (rs1), "r" (rs2)); \
  })

// rd <- 0(rs1)
#define uncached_read(rd, rs1) ({ \
  __asm__ __volatile__ (".insn i 0b0000011, 0b111, %0, %1, 0x0" : "=r" (rd) : "r" (rs1)); \
  })


int main()
{
  unsigned ret = -1;
  unsigned rs1 = 0;
  unsigned rs2 = 123;
  bsg_set_tile_x_y();
  uncached_write(rs1, rs2);
  uncached_read(ret, rs1);

  if(ret == rs2)
    bsg_finish();
  else
    bsg_fail();

  bsg_wait_while(1);
}

