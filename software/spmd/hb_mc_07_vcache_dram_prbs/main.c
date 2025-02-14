#include <stdint.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//#define N 536870912
//#define N (1UL<<25)
#define N 32768
#define VCACHE_LINE_WORDS 8
#define VCACHE_LINE_BYTES 32

int *dram_ptr = (int *) 0x80000000;

// Local storage;
uint8_t buffer[VCACHE_LINE_BYTES];

int main()
{
  bsg_set_tile_x_y();
  
  int stop = N/(bsg_tiles_Y*bsg_tiles_X);
  int* ptr = &dram_ptr[__bsg_id*stop];

  uint8_t curr = (__bsg_id + 1) & 0xff;
  uint32_t* buffer_word = (uint32_t*) &buffer[0];

  // store;
  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    // Generate PRBS-8 = x^8 + x^6 + x^5 + x^4 + 1
    for (int j = 0; j < VCACHE_LINE_BYTES; j++) {
      buffer[j] = curr;
      int newbit = ((curr >> 7) ^ (curr >> 5) ^ (curr >> 4) ^ (curr >> 3)) & 1;
      curr = ((curr << 1) | newbit) & 0xff;
    }
    ptr[i+0] = buffer_word[0];
    ptr[i+1] = buffer_word[1];
    ptr[i+2] = buffer_word[2];
    ptr[i+3] = buffer_word[3];
    ptr[i+4] = buffer_word[4];
    ptr[i+5] = buffer_word[5];
    ptr[i+6] = buffer_word[6];
    ptr[i+7] = buffer_word[7];
  }

  // load;
  curr = (__bsg_id + 1) & 0xff;
  uint32_t words[VCACHE_LINE_WORDS];

  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    // remote loads;
    words[0] = ptr[i+0]; 
    words[1] = ptr[i+1]; 
    words[2] = ptr[i+2]; 
    words[3] = ptr[i+3]; 
    words[4] = ptr[i+4]; 
    words[5] = ptr[i+5]; 
    words[6] = ptr[i+6]; 
    words[7] = ptr[i+7]; 
   
    // calculate expected;
    for (int j = 0; j < VCACHE_LINE_BYTES; j++) {
      buffer[j] = curr;
      int newbit = ((curr >> 7) ^ (curr >> 5) ^ (curr >> 4) ^ (curr >> 3)) & 1;
      curr = ((curr << 1) | newbit) & 0xff;
    }
 
    if (words[0] != buffer_word[0]) bsg_fail();
    if (words[1] != buffer_word[1]) bsg_fail();
    if (words[2] != buffer_word[2]) bsg_fail();
    if (words[3] != buffer_word[3]) bsg_fail();
    if (words[4] != buffer_word[4]) bsg_fail();
    if (words[5] != buffer_word[5]) bsg_fail();
    if (words[6] != buffer_word[6]) bsg_fail();
    if (words[7] != buffer_word[7]) bsg_fail();
  }

  bsg_finish();

  bsg_wait_while(1);
}

