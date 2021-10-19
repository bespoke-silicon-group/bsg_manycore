#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue_static.hpp"
#include "bsg_mcs_mutex.h"

#define JOBS 256

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


struct when_done {
    when_done() : done(nullptr) {}
    when_done(int *_done) : done(_done) {}
    void operator()() {
        bsg_print_hexadecimal((unsigned)(done));
        *done = 1;
    }
    int *done;
};

using queue = task_queue<when_done>;

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
      // dispatch jobs
      int _sync[JOBS] = {};
      int *syncp = bsg_tile_group_remote_pointer<int>(__bsg_x, __bsg_y, _sync);
          
      for (int i = 0; i < JOBS; i++) {
          queue::task job(&syncp[i]);
          job.clear();
          m.dispatch_now(&job);
      }

      for (int i = 0; i < JOBS; i++) {
          while (atomic_load(&_sync[i]) != 1);
          bsg_print_int(i);
      }
      
      // finish
      bsg_finish();
  } else {
      queue::worker w;
      w.init(&workq);
  }
  
  bsg_wait_while(1);
}
