#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

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

