#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"


#define N (64)
// sum from 0 to 63
#define ANSWER 2016 
int data[N*(bsg_tiles_X*bsg_tiles_Y)] __attribute__ ((section (".dram"))) = {0};
float fdata[N*(bsg_tiles_X*bsg_tiles_Y)] __attribute__ ((section (".dram"))) = {0.0f};


// HW barrier config
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

// AMOADD barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;



int main()
{
  bsg_set_tile_x_y();
 
  // calculate barcfg
  if (__bsg_id == 0) {
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
  }
  bsg_fence();
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);  

  int my_barcfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (my_barcfg));

  int i;
 
  // set up data
  int* mydata = &data[__bsg_id*N];
  float* myfdata = &fdata[__bsg_id*N];
  bsg_unroll(8)
  for (i = 0; i < N; i++) {
    mydata[i] = i;
  }
  bsg_unroll(8)
  for (i = 0; i < N; i++) {
    myfdata[i] = (float) i;
  }

  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  
  // accumulator
  int sum;
  float fsum;

  // test1: unroll by 4
  sum = 0;
  for (i = 0; i < N; i+=4) {
    register int temp0 = mydata[i+0];
    register int temp1 = mydata[i+1];
    register int temp2 = mydata[i+2];
    register int temp3 = mydata[i+3];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3);
  }
  if (sum != ANSWER) bsg_fail();

  // test2: unroll by 5
  sum = 0;
  for (i = 0; i < N-5+1; i+=5) {
    register int temp0 = mydata[i+0];
    register int temp1 = mydata[i+1];
    register int temp2 = mydata[i+2];
    register int temp3 = mydata[i+3];
    register int temp4 = mydata[i+4];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3 + temp4);
  }
  for (; i < N; i++) {
    sum += mydata[i];   
  }
  if (sum != ANSWER) bsg_fail();


  // test3: unroll by 7, with bubble in the middle
  sum = 0;
  for (i = 0; i < N-7+1; i+=7) {
    register int temp0 = mydata[i+0];
    register int temp1 = mydata[i+1];
    register int temp2 = mydata[i+2];
    register int temp3 = mydata[i+3];
    register int temp4 = mydata[i+4];
    asm volatile("nop":::);
    register int temp5 = mydata[i+5];
    register int temp6 = mydata[i+6];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3 + temp4 + temp5 + temp6);
  }
  for (; i < N; i++) {
    sum += mydata[i];   
  }
  if (sum != ANSWER) bsg_fail();
  

  //test4: unroll by 4 float 
  fsum = 0.0f;
  for (i = 0; i < N; i+=4) {
    register float temp0 = myfdata[i+0];
    register float temp1 = myfdata[i+1];
    register float temp2 = myfdata[i+2];
    register float temp3 = myfdata[i+3];
    asm volatile("": : :"memory");
    fsum += (temp0 + temp1 + temp2 + temp3);
  }
  if (fsum != 2016.0f) bsg_fail();


  //test5: unroll by 9 float 
  fsum = 0.0f;
  for (i = 0; i < N-9+1; i+=9) {
    register float temp0 = myfdata[i+0];
    register float temp1 = myfdata[i+1];
    register float temp2 = myfdata[i+2];
    register float temp3 = myfdata[i+3];
    register float temp4 = myfdata[i+4];
    register float temp5 = myfdata[i+5];
    register float temp6 = myfdata[i+6];
    register float temp7 = myfdata[i+7];
    register float temp8 = myfdata[i+8];
    asm volatile("": : :"memory");
    fsum += (temp0 + temp1 + temp2 + temp3 + temp4 + temp5 + temp6 + temp7 + temp8);
  }
  for (; i < N; i++) {
    fsum += myfdata[i];   
  }
  if (fsum != 2016.0f) bsg_fail();

  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  if (__bsg_id == 0) {
    bsg_finish();
  }
  bsg_wait_while(1);
}

