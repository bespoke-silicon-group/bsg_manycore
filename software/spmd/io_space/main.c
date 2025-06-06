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
  const unsigned max_addr = (1UL << 29);
  const unsigned min_addr = (1UL << 10);
  bsg_set_tile_x_y();

  // Any tile would work. Choose (0, 0).
  if((__bsg_x == 0) && (__bsg_y == 0)) {
    // Write phase
    for(unsigned upper = min_addr;upper <= max_addr;upper <<= 1) {
      unsigned addr = upper - min_addr;
      unsigned write_val = addr;
      io_write(addr, write_val);
    }
    // Read phase
    for(unsigned upper = min_addr;upper <= max_addr;upper <<= 1) {
      unsigned addr = upper - min_addr;    
      unsigned read_val = -1U;
      io_read(read_val, addr);
      if(read_val != addr)
        bsg_fail();
    }
  }

  bsg_finish();
  bsg_wait_while(1);
}

