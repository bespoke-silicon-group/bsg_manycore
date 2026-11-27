// Uncached IO requests while the vcaches fill and evict.
//
// Every tile writes more DRAM blocks than the vcaches hold in total, so
// the vcaches keep fetching and writing back blocks. In between, the tile
// writes and reads words of the IO space with the uncached load and store,
// through every vcache of the pod in turn. At the end, the tile reads back
// every DRAM word and every IO word that it wrote.

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

#define NUM_TILES (bsg_tiles_X*bsg_tiles_Y)

// DRAM blocks written by one tile. All tiles together write four times
// the number of blocks that the vcaches hold.
#define VCACHE_CAPACITY_BLOCKS (VCACHE_CAPACITY_WORDS/VCACHE_BLOCK_SIZE_WORDS)
#define NUM_BLOCKS ((4*VCACHE_CAPACITY_BLOCKS)/NUM_TILES)

// One IO word is written for this many DRAM blocks.
#define IO_PERIOD 4
#define NUM_IO_WORDS (NUM_BLOCKS/IO_PERIOD)

// The DRAM words of the tiles start here, well above the program.
#define DRAM_BASE 0x84000000

// Width of the vcache column field of an IO address.
#define X_FIELD_WIDTH ((bsg_global_X > 8) ? 4 : (bsg_global_X > 4) ? 3 : (bsg_global_X > 2) ? 2 : 1)

static inline unsigned dram_val(unsigned id, unsigned i)
{
  return (id << 24) ^ (i * 0x9e3779b1) ^ 0xd7a30000;
}

static inline unsigned io_val(unsigned id, unsigned j)
{
  return (id << 24) ^ (j * 0x85ebca6b) ^ 0x10c00000;
}

// The j-th IO word of a tile. The vcache that carries the request changes
// with every word. The word address is used by no other tile and by no
// other j, whichever vcache carries it.
static inline unsigned io_addr(unsigned id, unsigned j)
{
  unsigned vc = id + j;
  unsigned south = vc & 1;
  unsigned x = (vc >> 1) % bsg_global_X;
  unsigned word = (id * NUM_IO_WORDS) + j;
  return (south << 31) | (x << (31-X_FIELD_WIDTH)) | (word << 2);
}

int main()
{
  bsg_set_tile_x_y();

  unsigned id = __bsg_id;
  // one block per write, so that every write touches a new block.
  volatile unsigned *dram = (volatile unsigned *) (DRAM_BASE + (id * NUM_BLOCKS * VCACHE_BLOCK_SIZE_WORDS * 4));

  for (unsigned i = 0; i < NUM_BLOCKS; i++) {
    dram[i*VCACHE_BLOCK_SIZE_WORDS] = dram_val(id, i);

    if ((i % IO_PERIOD) == 0) {
      unsigned j = i / IO_PERIOD;
      io_write(io_addr(id, j), io_val(id, j));
      // the word before this one went out earlier, through another vcache.
      if (j > 0) {
        unsigned r;
        io_read(r, io_addr(id, j-1));
        if (r != io_val(id, j-1)) bsg_fail();
      }
    }
  }

  bsg_fence();

  for (unsigned i = 0; i < NUM_BLOCKS; i++) {
    if (dram[i*VCACHE_BLOCK_SIZE_WORDS] != dram_val(id, i)) bsg_fail();

    if ((i % IO_PERIOD) == 0) {
      unsigned j = i / IO_PERIOD;
      unsigned r;
      io_read(r, io_addr(id, j));
      if (r != io_val(id, j)) bsg_fail();
    }
  }

  bsg_finish();
  bsg_wait_while(1);
}
