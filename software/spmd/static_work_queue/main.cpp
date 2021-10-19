#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue_static.hpp"
#include "bsg_mcs_mutex.h"

#define JOBS 100

__attribute__((section(".dram")))
int b_l = 0;
int b_s = 1;
extern "C" void bsg_barrier_amoadd(int *l, int *s);

struct say_hi {
    say_hi(){}
    void operator()() {
        bsg_print_int(__bsg_id);
    }
};

using queue = task_queue<decltype(say_hi())>;

__attribute__((section(".dram")))
queue workq;

//#define DEBUG
int main()
{

  bsg_set_tile_x_y();

  queue::manager m;
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2)
      m.init(&workq);

  bsg_barrier_amoadd(&b_l, &b_s);
  
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2) {
      // jobs
      queue::task job [JOBS];

      // enqueue jobs
      for (int i = 0; i < JOBS; i++) {
          job[i].clear();
          m.dispatch_now(&job[i]);
      }

      // dispatch all jobs
      // manager_dispatch_all(&m);

      for (volatile int i = 0; i < 100; i++);
      
      // finish
      bsg_finish();
  } else {
      queue::worker w;
      w.init(&workq);
  }
  
  bsg_wait_while(1);
}
