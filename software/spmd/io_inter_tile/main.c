#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

// 0(rs1) <- rs2
#define io_write(rs1, rs2) ({ \
  __asm__ __volatile__ (".insn r 0b0100011, 0b111, 0x0, x0, %0, %1" : : "r" (rs1), "r" (rs2)); \
  })

// rd <- 0(rs1)
#define io_read(rd, rs1) ({ \
  __asm__ __volatile__ (".insn i 0b0000011, 0b111, %0, %1, 0x0" : "=r" (rd) : "r" (rs1)); \
  })

int main()
{
  unsigned read_val = -1U;
  unsigned addr = 0;
  unsigned write_val = 0xDEADDEAD;
  bsg_set_tile_x_y();

  if((__bsg_x == 0) && (__bsg_y == 0)) {
    io_write(addr, write_val);
  }
  else if((__bsg_x == 1) && (__bsg_y == 0)) {
    while(read_val != write_val) {
      io_read(read_val, addr);
    }
  }

  bsg_finish();
  bsg_wait_while(1);
}

