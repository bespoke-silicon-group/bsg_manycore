#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#if bsg_tiles_X != 4
#error "bsg_tiles_X should be 4"
#elif bsg_tiles_Y != 4
#error "bsg_tiles_Y should be 4"
#endif

// CRC-32 polynomial
#define CRC_32_POLY 0xEDB88320

#define VEC_LEN     32

#define XY_ID(x, y) ((x + (y*bsg_tiles_X)) << 24)
#define NODE_VEC(x, y) { \
    0x00 | XY_ID(x, y), \
    0x01 | XY_ID(x, y), \
    0x02 | XY_ID(x, y), \
    0x03 | XY_ID(x, y), \
    0x04 | XY_ID(x, y), \
    0x05 | XY_ID(x, y), \
    0x06 | XY_ID(x, y), \
    0x07 | XY_ID(x, y), \
    0x08 | XY_ID(x, y), \
    0x09 | XY_ID(x, y), \
    0x0a | XY_ID(x, y), \
    0x0b | XY_ID(x, y), \
    0x0c | XY_ID(x, y), \
    0x0d | XY_ID(x, y), \
    0x0e | XY_ID(x, y), \
    0x0f | XY_ID(x, y), \
    0x10 | XY_ID(x, y), \
    0x11 | XY_ID(x, y), \
    0x12 | XY_ID(x, y), \
    0x13 | XY_ID(x, y), \
    0x14 | XY_ID(x, y), \
    0x15 | XY_ID(x, y), \
    0x16 | XY_ID(x, y), \
    0x17 | XY_ID(x, y), \
    0x18 | XY_ID(x, y), \
    0x19 | XY_ID(x, y), \
    0x1a | XY_ID(x, y), \
    0x1b | XY_ID(x, y), \
    0x1c | XY_ID(x, y), \
    0x1d | XY_ID(x, y), \
    0x1e | XY_ID(x, y), \
    0x1f | XY_ID(x, y)  \
}
#define ROW_VEC(y) { \
    NODE_VEC(0, y), \
    NODE_VEC(1, y), \
    NODE_VEC(2, y), \
    NODE_VEC(3, y)  \
}

// All tiles hold the data
int Data[bsg_tiles_Y][bsg_tiles_X][VEC_LEN] = {
    ROW_VEC(0),
    ROW_VEC(1),
    ROW_VEC(2),
    ROW_VEC(3)
};

// Routine to caclulate CRC-32 of 32-bit words
// in the memory.
int crc32(int *addr, int size) {
    int crc = 0xffffffff;

    for (int i=0; i<size; i++) {
        crc = crc ^ *(addr++);
        for (i=0; i<32; i++) {
          if (crc & 1)
            crc = (crc >> 1) ^ CRC_32_POLY;
          else
            crc >>= 1;
        }
    }

    return crc;
}

void proc0() {
    int check_sum0;

    // Iterate on all coordinates
    for(int y=0; y<bsg_tiles_Y; y++) {
        for(int x=0; x<bsg_tiles_X; x++) {
            int data_vec[VEC_LEN] = {};
            int check_sum;

            // Load data vector from each tile
            for(int i=0; i<VEC_LEN; i++) {
                data_vec[i] = *bsg_remote_ptr(x, y, &Data[y][x][i]);

                // Word loaded from a tile has it's "tile id" in as the
                // MSB byte. Hence XOR with tile id to extract the data.
                data_vec[i] = data_vec[i] ^ (XY_ID(x, y));
            }

            // CRC-32 checksum of the data vector
            check_sum = crc32(data_vec, VEC_LEN);
            bsg_remote_ptr_io_store(IO_X_INDEX, 0, check_sum);

            // Compare check sum of tile 0 to that of rest of 
            // the tiles. Since data loaded from all tiles is
            // the same, CRC should also be the same.
            if(x==0 && y==0) {
                check_sum0 = check_sum;
            } else if(check_sum != check_sum0) {
                bsg_fail();
            }
        }
    }

    bsg_finish();
}


int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  if(id == 0) proc0();

  bsg_wait_while(1);
}
