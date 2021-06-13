// this tests the behavior of the pod csr
//
// it writes a small amount of data to every pod's memory space;
// and reads it back and checks it.
//
// while it does this, with the CSR pointing somewhere else, it
// does a bunch of recursion on the stack, and also writes to
// an array on the stack.
//
//


#define riscv_nop() __asm__ __volatile ("addi x0,x0,0" ::: "memory")

#define swap_csr(reg, val) ({ unsigned long __tmp; \
      __asm__ __volatile__ ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "r"(val) : "memory"); \
  __tmp; })

#define bsg_pod_csr(val) swap_csr(0x360,val)

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#define N 32
#define ANSWER 523776

int data[N] __attribute__ ((section (".dram"))) = {0};

#define ITER 4


int recur(int iters, int val)
{
  if (iters > 0)
    return recur(iters-1,val^val + 1);
  else
    return val ^ 0x343;
}


int main()
{
  volatile int tmp[N][4][4];
  bsg_set_tile_x_y();
  bsg_print_int(0x8000);
  int old = bsg_pod_csr((1 << 3) + 1);
  bsg_print_int(0xA000);
  for (int i = 0; i < ITER; i++)
    for (int py = 0; py < num_pods_Y; py++)
      {
	int y_pod = py*2+1;
	
	for (int px = 0; px < num_pods_X; px++)
	  {
	    int x_pod = px + 1;
	    bsg_pod_csr(x_pod + (y_pod << 3));
	    data[i] = i+(px<<4)+py;
	  }
      }

  // flush icache
  #pragma GCC unroll 1024
  for (int j = 0; j < 1024; j++)
    riscv_nop();

  int x = recur(40,0xDEADBEEF);
  bsg_print_int(x);
  bsg_print_int(0xC000);

  for (int i = 0; i < ITER; i++)
    for (int px = 0; px < num_pods_X; px++)
      {
	int x_pod = px + 1;
	for (int py = 0; py < num_pods_Y; py++)
	  {
	    int y_pod = py*2+1;
	    bsg_pod_csr(x_pod + (y_pod << 3));
	    int val = data[i];
	    tmp[i][px][py] = val;
	    bsg_print_int(val);
	    if (val != i+(px<<4)+py)
	      bsg_fail();
	  }
      }

  // check that locally stored version is okay
  for (int i = 0; i < ITER; i++)
    for (int px = 0; px < num_pods_X; px++)
      for (int py = 0; py < num_pods_Y; py++)      
	if (tmp[i][px][py] != i+(px<<4)+py)
	      bsg_fail();

  bsg_pod_csr(old);


  bsg_finish();

  bsg_wait_while(1);
}
