#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 64
// sum from 0 to 63
#define ANSWER 2016 
int data[N] __attribute__ ((section (".dram"))) = {0};
float fdata[N] __attribute__ ((section (".dram"))) = {0.0f};


int main()
{
  bsg_set_tile_x_y();
  
  // set up data
  for (int i = 0; i < N; i++) {
    data[i] = i;
    fdata[i] = (float) i;
  }

  bsg_fence();
  
  // accumulator
  int sum;
  float fsum;
  
  int i;

  // test1: unroll by 4
  sum = 0;
  for (i = 0; i < N; i+=4) {
    register int temp0 = data[i+0];
    register int temp1 = data[i+1];
    register int temp2 = data[i+2];
    register int temp3 = data[i+3];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3);
  }
  if (sum != ANSWER) bsg_fail();


  // test2: unroll by 5
  sum = 0;
  for (i = 0; i < N-5+1; i+=5) {
    register int temp0 = data[i+0];
    register int temp1 = data[i+1];
    register int temp2 = data[i+2];
    register int temp3 = data[i+3];
    register int temp4 = data[i+4];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3 + temp4);
  }
  for (; i < N; i++) {
    sum += data[i];   
  }
  if (sum != ANSWER) bsg_fail();


  // test2: unroll by 7, with bubble in the middle
  sum = 0;
  for (i = 0; i < N-7+1; i+=7) {
    register int temp0 = data[i+0];
    register int temp1 = data[i+1];
    register int temp2 = data[i+2];
    register int temp3 = data[i+3];
    register int temp4 = data[i+4];
    asm volatile("nop":::);
    register int temp5 = data[i+5];
    register int temp6 = data[i+6];
    asm volatile("": : :"memory");
    sum += (temp0 + temp1 + temp2 + temp3 + temp4 + temp5 + temp6);
  }
  for (; i < N; i++) {
    sum += data[i];   
  }
  if (sum != ANSWER) bsg_fail();
  

  //test4: unroll by 4 float 
  fsum = 0.0f;
  for (i = 0; i < N; i+=4) {
    register float temp0 = fdata[i+0];
    register float temp1 = fdata[i+1];
    register float temp2 = fdata[i+2];
    register float temp3 = fdata[i+3];
    asm volatile("": : :"memory");
    fsum += (temp0 + temp1 + temp2 + temp3);
  }
  if (fsum != 2016.0f) bsg_fail();


  //test5: unroll by 9 float 
  fsum = 0.0f;
  for (i = 0; i < N-9+1; i+=9) {
    register float temp0 = fdata[i+0];
    register float temp1 = fdata[i+1];
    register float temp2 = fdata[i+2];
    register float temp3 = fdata[i+3];
    register float temp4 = fdata[i+4];
    register float temp5 = fdata[i+5];
    register float temp6 = fdata[i+6];
    register float temp7 = fdata[i+7];
    register float temp8 = fdata[i+8];
    asm volatile("": : :"memory");
    fsum += (temp0 + temp1 + temp2 + temp3 + temp4 + temp5 + temp6 + temp7 + temp8);
  }
  for (; i < N; i++) {
    fsum += fdata[i];   
  }
  if (fsum != 2016.0f) bsg_fail();



  bsg_finish();
  bsg_wait_while(1);
}

