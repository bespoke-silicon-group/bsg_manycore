// One tile sends uncached requests through every vcache of the machine.
//
// The IO pod register selects the pod of the vcache, and the address selects
// its row and its column. The tile first writes a different value through
// each vcache, always to the same IO word address, and then reads all of
// them back. The test memory keeps one IO space for each vcache, so every
// value is still there only if every pod, row and column led to a different
// vcache.
//
// The IO pod register is separate from the pod register of the DRAM
// requests. The test checks both directions:
// - While the IO pod register points to another pod, the tile reads and
//   writes arrays in the DRAM of its own pod.
// - While the DRAM pod register points to another pod, the tile reads the IO
//   words behind its own pod again.

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

// Both pod registers hold {pod y, pod x} and are this tile's own pod after
// reset. CSR 0x360 is for DRAM requests and CSR 0x361 for uncached requests.
#define dram_pod_csr_read() ({ unsigned __v; \
  __asm__ __volatile__ ("csrr %0, 0x360" : "=r" (__v)); \
  __v; })
#define io_pod_csr_read() ({ unsigned __v; \
  __asm__ __volatile__ ("csrr %0, 0x361" : "=r" (__v)); \
  __v; })
// A write to the DRAM pod register changes what every pointer to DRAM means.
// "memory" keeps the compiler from moving a DRAM access across it.
#define dram_pod_csr_write(val) ({ \
  __asm__ __volatile__ ("csrw 0x360, %0" : : "r" (val) : "memory"); \
  })
#define io_pod_csr_write(val) ({ \
  __asm__ __volatile__ ("csrw 0x361, %0" : : "r" (val)); \
  })

// Width of the vcache column field of an IO address.
#define X_FIELD_WIDTH ((bsg_global_X > 8) ? 4 : (bsg_global_X > 4) ? 3 : (bsg_global_X > 2) ? 2 : 1)
// Width of the pod x field of a pod register: what an x coordinate has above the column.
#define POD_X_WIDTH (X_CORD_WIDTH - X_FIELD_WIDTH)

#define IO_WORD_ADDR 0x40

#define NUM_VCACHES (num_pods_X * num_pods_Y * 2 * bsg_global_X)

// In the DRAM of this tile's pod.
unsigned expected[NUM_VCACHES] __attribute__ ((section (".dram")));
unsigned written[NUM_VCACHES] __attribute__ ((section (".dram")));

static inline unsigned io_addr(unsigned row, unsigned col)
{
  return (row << 31) | (col << (31-X_FIELD_WIDTH)) | IO_WORD_ADDR;
}

static inline unsigned io_val(unsigned px, unsigned py, unsigned row, unsigned col)
{
  return 0x5e1ec700 ^ (py << 24) ^ (px << 16) ^ (row << 12) ^ col;
}

static inline unsigned vcache_idx(unsigned px, unsigned py, unsigned row, unsigned col)
{
  return ((py * num_pods_X + px) * 2 + row) * bsg_global_X + col;
}

int main()
{
  bsg_set_tile_x_y();

  // This tile is in the first pod. The pod next to it in x is one higher in
  // the pod x field, and the next pod row is two higher in the pod y field:
  // the vcache rows lie in between.
  unsigned own_pod = dram_pod_csr_read();
  if (io_pod_csr_read() != own_pod)
    bsg_fail();

  // What each vcache will get, kept in DRAM. Written while both registers
  // point to this pod.
  for (unsigned py = 0; py < num_pods_Y; py++)
    for (unsigned px = 0; px < num_pods_X; px++)
      for (unsigned row = 0; row < 2; row++)
        for (unsigned col = 0; col < bsg_global_X; col++)
          expected[vcache_idx(px, py, row, col)] = io_val(px, py, row, col);

  // Write through every vcache. The stores to written[] go to this pod's
  // DRAM whatever the IO pod register says.
  for (unsigned py = 0; py < num_pods_Y; py++) {
    for (unsigned px = 0; px < num_pods_X; px++) {
      unsigned io_pod = own_pod + px + ((2*py) << POD_X_WIDTH);
      io_pod_csr_write(io_pod);
      if (io_pod_csr_read() != io_pod || dram_pod_csr_read() != own_pod)
        bsg_fail();
      for (unsigned row = 0; row < 2; row++) {
        for (unsigned col = 0; col < bsg_global_X; col++) {
          unsigned v = io_val(px, py, row, col);
          io_write(io_addr(row, col), v);
          written[vcache_idx(px, py, row, col)] = v;
        }
      }
    }
  }

  // Read through every vcache, and compare with expected[], which is read
  // from this pod's DRAM while the IO pod register points to another pod.
  for (unsigned py = 0; py < num_pods_Y; py++) {
    for (unsigned px = 0; px < num_pods_X; px++) {
      io_pod_csr_write(own_pod + px + ((2*py) << POD_X_WIDTH));
      for (unsigned row = 0; row < 2; row++) {
        for (unsigned col = 0; col < bsg_global_X; col++) {
          unsigned r;
          io_read(r, io_addr(row, col));
          if (r != io_val(px, py, row, col) || r != expected[vcache_idx(px, py, row, col)])
            bsg_fail();
        }
      }
    }
  }

  io_pod_csr_write(own_pod);

  // The stores made while the IO pod register pointed to other pods.
  for (unsigned i = 0; i < NUM_VCACHES; i++)
    if (written[i] != expected[i])
      bsg_fail();

  // The other direction, on a machine with more than one pod: the DRAM pod
  // register points to another pod, and the IO behind this tile's own pod is
  // read again. Nothing in DRAM is used in between.
  if (num_pods_X > 1 || num_pods_Y > 1) {
    unsigned other_pod = (num_pods_X > 1) ? (own_pod + 1) : (own_pod + (2 << POD_X_WIDTH));
    dram_pod_csr_write(other_pod);
    if (io_pod_csr_read() != own_pod) {
      dram_pod_csr_write(own_pod);
      bsg_fail();
    }
    for (unsigned row = 0; row < 2; row++) {
      for (unsigned col = 0; col < bsg_global_X; col++) {
        unsigned r;
        io_read(r, io_addr(row, col));
        if (r != io_val(0, 0, row, col)) {
          dram_pod_csr_write(own_pod);
          bsg_fail();
        }
      }
    }
    dram_pod_csr_write(own_pod);
  }

  bsg_finish();
  bsg_wait_while(1);
}
