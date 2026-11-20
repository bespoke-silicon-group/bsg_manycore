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

void iteration(unsigned base_addr)
{

  // word size == 4 bytes; 16 tiles in total
  unsigned addr0 = base_addr + __bsg_id * 4 * 8 + 0;
  unsigned addr1 = base_addr + __bsg_id * 4 * 8 + 4;
  unsigned addr2 = base_addr + __bsg_id * 4 * 8 + 8;
  unsigned addr3 = base_addr + __bsg_id * 4 * 8 + 12;
  unsigned addr4 = base_addr + __bsg_id * 4 * 8 + 16;
  unsigned addr5 = base_addr + __bsg_id * 4 * 8 + 20;
  unsigned addr6 = base_addr + __bsg_id * 4 * 8 + 24;
  unsigned addr7 = base_addr + __bsg_id * 4 * 8 + 28;
  unsigned read_val0;
  unsigned read_val1;
  unsigned read_val2;
  unsigned read_val3;
  unsigned read_val4;
  unsigned read_val5;
  unsigned read_val6;
  unsigned read_val7;
  unsigned val0 = addr0 + 28;
  unsigned val1 = addr1 + 24;
  unsigned val2 = addr2 + 20;
  unsigned val3 = addr3 + 16;
  unsigned val4 = addr4 + 12;
  unsigned val5 = addr5 + 8;
  unsigned val6 = addr6 + 4;
  unsigned val7 = addr7 + 0;
  io_write(addr0, val0);
  io_write(addr1, val1);
  io_write(addr2, val2);
  io_write(addr3, val3);
  io_write(addr4, val4);
  io_write(addr5, val5);
  io_write(addr6, val6);
  io_write(addr7, val7);
  bsg_fence();
  io_write(addr0, val0);
  io_read(read_val0, addr0);
  io_write(addr1, val1);
  io_read(read_val1, addr1);
  io_write(addr2, val2);
  io_read(read_val2, addr2);
  io_write(addr3, val3);
  io_read(read_val3, addr3);
  io_write(addr4, val4);
  io_read(read_val4, addr4);
  io_write(addr5, val5);
  io_read(read_val5, addr5);
  io_write(addr6, val6);
  io_read(read_val6, addr6);
  io_write(addr7, val7);
  io_read(read_val7, addr7);
  bsg_fence();
  io_read(read_val0, addr0);
  io_read(read_val1, addr1);
  io_read(read_val2, addr2);
  io_read(read_val3, addr3);
  io_read(read_val4, addr4);
  io_read(read_val5, addr5);
  io_read(read_val6, addr6);
  io_read(read_val7, addr7);

  unsigned sum = (read_val0 == val0)
    + (read_val1 == val1)
    + (read_val2 == val2)
    + (read_val3 == val3)
    + (read_val4 == val4)
    + (read_val5 == val5)
    + (read_val6 == val6)
    + (read_val7 == val7);
  if(sum != 8)
    bsg_fail();
}

int main()
{
  const unsigned max_addr = (1U << 29);
  const unsigned min_addr = (1U << 10);
  bsg_set_tile_x_y();

  iteration(0);
  for(unsigned base_addr = min_addr;base_addr < max_addr;base_addr <<= 1) {
    iteration(base_addr);
  }

  bsg_finish();
}

