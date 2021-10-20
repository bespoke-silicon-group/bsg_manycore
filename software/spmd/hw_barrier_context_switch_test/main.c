// Each tile runs N (=NUM_THREAD) independing threads running work().
// When the tile receives a remote interrupt, it context switches to the next thread.
// Each thread has its own context including DMEM, register file contents, barrier states.
// At the end of work, each thread sends a finish packet if every thing worked correctly.
// The simulation terminates when the host has receives NUM_THREAD*NUM_TILES of finish packets.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_hw_barrier.h"
#include "bsg_hw_barrier_config_init.h"

#define NUM_ITER 4
#define NUM_WORD 8

// barrier config
int barcfg[bsg_tiles_X*bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

// thread id
int __thread_id = 0;

// thread data block
int _thread_data_block[bsg_tiles_X*bsg_tiles_Y*NUM_THREAD*1024] __attribute__ ((section (".dram"))) = {0}; 

// thread context block (64 words)
// thread id [0]
// x1~x31 [1:31]
// barrier entered [32]
// mepc [33]
int _thread_context_block[bsg_tiles_X*bsg_tiles_Y*NUM_THREAD*64] __attribute__ ((section (".dram"))) = {0};


// amoadd barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;
int amoadd_lock2 __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm2 = 1;


// private data
int  mydata[NUM_WORD] = {0};


void work() {
  for (int i  = 0; i < NUM_ITER; i++) {
  
    // last tile interrupts everyone
    if (__bsg_id == (bsg_tiles_X*bsg_tiles_Y)-1) {
      for (int y = 0; y < bsg_tiles_Y; y++) {
        for (int x = 0; x < bsg_tiles_X; x++) {
          bsg_remote_store(x,y,0xfffc,1);
        }
      }     
    }  


    int temp[NUM_WORD];
    int tx = (__bsg_x + i) % bsg_tiles_X;
    int ty = (__bsg_y + i) % bsg_tiles_Y;

    for (int j = 0; j < NUM_WORD; j++) {
      bsg_remote_load(tx, ty, &mydata[j], temp[j]);
    }

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();

    for (int j = 0; j < NUM_WORD; j++) {
      temp[j] = temp[j] + 1;
      bsg_remote_store(tx, ty, &mydata[j], temp[j]);
    }

    bsg_fence();
    bsg_barsend();
    bsg_barrecv();
  }


  // validate
  if (__bsg_id == 0) {
    for (int y = 0; y < bsg_tiles_Y; y++) {
      for (int x = 0; x < bsg_tiles_X; x++) {
        for (int i = 0; i < NUM_WORD; i++) {
          int temp = -1;
          bsg_remote_load(x,y,&mydata[i],temp);
          if (temp != NUM_ITER) {
            bsg_fail();
          }
        }
      }
    }
    
    // send finish packet; and don't get into while(1) after that...
    bsg_global_store(IO_X_INDEX, IO_Y_INDEX, 0xEAD0, 1);
  }

  while (1) {
    bsg_remote_store(__bsg_x,__bsg_y,0xfffc,1);
    bsg_fence();
  }
}

int main()
{
  bsg_set_tile_x_y();

  // initialize barcfg
  if (__bsg_id == 0) {
    bsg_hw_barrier_config_init(barcfg, bsg_tiles_X, bsg_tiles_Y);
    bsg_fence();
  }
  
  bsg_barrier_amoadd(&amoadd_lock2, &amoadd_alarm2);


  // config hw barrier
  int cfg = barcfg[__bsg_id];
  asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));


  // enable remote_interrupt
  asm volatile ("csrrs x0, mstatus, %0" : : "r" (0x8));
  asm volatile ("csrrs x0, mie, %0" : : "r" (0x10000));


  // set up thread context block
  int* myblock = &_thread_context_block[64*NUM_THREAD*__bsg_id];
  for (int n = 0; n < NUM_THREAD; n++) {
    myblock[(64*n)+0] = n;    // thread id
    myblock[(64*n)+2] = 4096; // sp
    myblock[(64*n)+33] = (int) work; // mepc
  }
  
  // set up thread data block
  int* my_datablock = &_thread_data_block[1024*NUM_THREAD*__bsg_id];
  for (int n = 0; n < NUM_THREAD; n++) {
    my_datablock[(1024*n)+(((int) &__bsg_id)/4)] = __bsg_id;
    my_datablock[(1024*n)+(((int) &__bsg_x)/4)]  = __bsg_x;
    my_datablock[(1024*n)+(((int) &__bsg_y)/4)]  = __bsg_y;
  }

  // make sure that everyone has set up threads, before allow sending interrupts.
  bsg_fence();
  bsg_barsend();
  bsg_barrecv();

  // start threads
  work();
}
