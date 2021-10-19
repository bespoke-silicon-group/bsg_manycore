#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"
#include "bsg_mcs_mutex.h"

#define JOBS 100

__attribute__((section(".dram")))
int b_l = 0;
int b_s = 1;
extern "C" void bsg_barrier_amoadd(int *l, int *s);

__attribute__((section(".dram")))
task_queue workq;

//#define DEBUG
int main()
{

  bsg_set_tile_x_y();

  manager m;
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2)
      manager_init(&m, &workq);

  bsg_barrier_amoadd(&b_l, &b_s);
  
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2) {
      // jobs
      job<1> job [JOBS];
      int  _sync [JOBS] = {};
      int *sync = bsg_tile_group_remote_pointer(__bsg_x, __bsg_y, _sync);

      // enqueue jobs
      for (int i = 0; i < JOBS; i++) {
          task_clear(&job[i].t);
          // enqueue a job with sync
          manager_dispatch_job_now_sync(
              &m, &job[i] , &sync[i]
              , [] (task *t) {
                  bsg_print_int(t->data[0]);
              }
              , i);
      }

      // dispatch all jobs
      // manager_dispatch_all(&m);

      // wait for jobs to complete
      for (int i = 0; i < JOBS; i++) {
          int *sp = bsg_tile_group_remote_pointer(__bsg_x, __bsg_y, &_sync[i]);
          while (atomic_load(sp) != 1);
      }

      // finish
      bsg_finish();
  } else {
      worker w;
      worker_init(&w, &workq);
  }
  
  bsg_wait_while(1);
}
