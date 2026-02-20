#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 536870912
//#define N 32768
#define VCACHE_LINE_WORDS 8

#define OVERRIDE 0

int *dram_ptr = (int *) 0x80000000;

int main()
{
  bsg_set_tile_x_y();
  
  int stop = N/(bsg_tiles_Y*bsg_tiles_X);
  int* ptr = &dram_ptr[__bsg_id*stop];

  // store;
  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    ptr[i+0] = __bsg_id*stop+i+(OVERRIDE==0?0:5);
    ptr[i+1] = __bsg_id*stop+i+(OVERRIDE==0?1:5);
    ptr[i+2] = __bsg_id*stop+i+(OVERRIDE==0?2:5);
    ptr[i+3] = __bsg_id*stop+i+(OVERRIDE==0?3:5);
    ptr[i+4] = __bsg_id*stop+i+(OVERRIDE==0?4:5);
    ptr[i+5] = __bsg_id*stop+i+(OVERRIDE==0?5:5);
    ptr[i+6] = __bsg_id*stop+i+(OVERRIDE==0?6:5);
    ptr[i+7] = __bsg_id*stop+i+(OVERRIDE==0?7:5);
  }

  // load;
  int words[VCACHE_LINE_WORDS];

  int error = 0;

  bsg_unroll(1)
  for (int i = 0; i < stop; i+=VCACHE_LINE_WORDS) {
    words[0] = ptr[i+0]; 
    words[1] = ptr[i+1]; 
    words[2] = ptr[i+2]; 
    words[3] = ptr[i+3]; 
    words[4] = ptr[i+4]; 
    words[5] = ptr[i+5]; 
    words[6] = ptr[i+6]; 
    words[7] = ptr[i+7]; 
    if (words[0] != __bsg_id*stop+i+(OVERRIDE==0?0:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?0:5), words[0]); error = 1;}
    if (words[1] != __bsg_id*stop+i+(OVERRIDE==0?1:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?1:5), words[1]); error = 1;}
    if (words[2] != __bsg_id*stop+i+(OVERRIDE==0?2:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?2:5), words[2]); error = 1;}
    if (words[3] != __bsg_id*stop+i+(OVERRIDE==0?3:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?3:5), words[3]); error = 1;}
    if (words[4] != __bsg_id*stop+i+(OVERRIDE==0?4:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?4:5), words[4]); error = 1;}
    if (words[5] != __bsg_id*stop+i+(OVERRIDE==0?5:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?5:5), words[5]); error = 1;}
    if (words[6] != __bsg_id*stop+i+(OVERRIDE==0?6:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?6:5), words[6]); error = 1;}
    if (words[7] != __bsg_id*stop+i+(OVERRIDE==0?7:5)) {bsg_printf("C=%X, A=%X\n", __bsg_id*stop+i+(OVERRIDE==0?7:5), words[7]); error = 1;}
    if (error == 1) bsg_fail();
  }

  bsg_finish();

  bsg_wait_while(1);
}

