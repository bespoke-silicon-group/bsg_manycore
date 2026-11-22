// One tile sends uncached requests through every vcache of the machine.
//
// The pod register selects the pod of the vcache, and the address selects
// its row and its column. The tile first writes a different value through
// each vcache, always to the same IO word address, and then reads all of
// them back. The test memory keeps one IO space for each vcache, so every
// value is still there only if every pod, row and column led to a different
// vcache.
//
// While the pod register points to another pod, DRAM requests go to that pod
// as well. The loops below therefore use no data in DRAM.

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

// The pod register is CSR 0x360 and holds {pod y, pod x}.
#define pod_csr_read() ({ unsigned __v; \
  __asm__ __volatile__ ("csrr %0, 0x360" : "=r" (__v)); \
  __v; })
#define pod_csr_write(val) ({ \
  __asm__ __volatile__ ("csrw 0x360, %0" : : "r" (val)); \
  })

// Width of the vcache column field of an IO address.
#define X_FIELD_WIDTH ((bsg_global_X > 8) ? 4 : (bsg_global_X > 4) ? 3 : (bsg_global_X > 2) ? 2 : 1)
// Width of the pod x field of the pod register: what an x coordinate has above the column.
#define POD_X_WIDTH (X_CORD_WIDTH - X_FIELD_WIDTH)

#define IO_WORD_ADDR 0x40

static inline unsigned io_addr(unsigned row, unsigned col)
{
  return (row << 31) | (col << (31-X_FIELD_WIDTH)) | IO_WORD_ADDR;
}

static inline unsigned io_val(unsigned px, unsigned py, unsigned row, unsigned col)
{
  return 0x5e1ec700 ^ (py << 24) ^ (px << 16) ^ (row << 12) ^ col;
}

int main()
{
  bsg_set_tile_x_y();

  // This tile is in the first pod. The pod next to it in x is one higher in
  // the pod x field, and the next pod row is two higher in the pod y field:
  // the vcache rows lie in between.
  unsigned own_pod = pod_csr_read();

  for (unsigned py = 0; py < num_pods_Y; py++) {
    for (unsigned px = 0; px < num_pods_X; px++) {
      bsg_fence();
      pod_csr_write(own_pod + px + ((2*py) << POD_X_WIDTH));
      for (unsigned row = 0; row < 2; row++)
        for (unsigned col = 0; col < bsg_global_X; col++)
          io_write(io_addr(row, col), io_val(px, py, row, col));
    }
  }

  for (unsigned py = 0; py < num_pods_Y; py++) {
    for (unsigned px = 0; px < num_pods_X; px++) {
      bsg_fence();
      pod_csr_write(own_pod + px + ((2*py) << POD_X_WIDTH));
      for (unsigned row = 0; row < 2; row++) {
        for (unsigned col = 0; col < bsg_global_X; col++) {
          unsigned r;
          io_read(r, io_addr(row, col));
          if (r != io_val(px, py, row, col)) {
            pod_csr_write(own_pod);
            bsg_fail();
          }
        }
      }
    }
  }

  bsg_fence();
  pod_csr_write(own_pod);

  bsg_finish();
  bsg_wait_while(1);
}
