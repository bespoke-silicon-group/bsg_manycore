#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"
#include "bsg_mcs_mutex.h"

#define JOBS 100

__attribute__((section(".dram")))
int b_l = 0;
int b_s = 1;
extern "C" void bsg_barrier_amoadd(int *l, int *s);

template <int N>
struct job {
    static constexpr int WORDS = N;
    task t;
    int  w [N-1];
};

template <>
struct job<0> {
    static constexpr int WORDS = 0;    
    task t;    
};

template <typename job_type>
static void manager_enqueue_job_0(manager *m, job_type *j)
{
    j->t.data_words = job_type::WORDS;
    manager_enqueue(m, &j->t);
}

template <int I, typename job_type>
static void manager_enqueue_job_unpack(manager *m, job_type *j)
{
    return;
}

template <int I, typename job_type, typename arg_type>
static void manager_enqueue_job_unpack(manager *m, job_type *j,  arg_type arg)
{
    j->t.data[I] = reinterpret_cast<int&>(arg);
}

template <int I, typename job_type, typename arg_type, typename ... arg_types>
static void manager_enqueue_job_unpack(manager *m, job_type *j, arg_type arg, arg_types ...args)
{
    j->t.data[I] = reinterpret_cast<int&>(arg);
    manager_enqueue_job_unpack<I+1>(m, j, args...);
}

template <typename job_type, typename ... arg_types>
static void manager_enqueue_job(manager *m, job_type *j,  void (*call)(task*), arg_types ...args)
{
    j->t.call = call;
    manager_enqueue_job_unpack<0>(m, j, args...);
    manager_enqueue_job_0(m, j);
}


template <typename job_type, typename ... arg_types>
static void manager_enqueue_job_sync(manager *m, job_type *j, int *sync, void (*call)(task*), arg_types ...args)
{
    j->t.done = sync;
    manager_enqueue_job(m, j, call, args...);
}

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
      job<2> job[JOBS];
      int  _sync [JOBS] = {};
      int *sync = bsg_tile_group_remote_pointer(__bsg_x, __bsg_y, _sync);

      // enqueue jobs
      for (int i = 0; i < JOBS; i++) {
          task_clear(&job[i].t);
          // enqueue a job with sync
          manager_enqueue_job_sync(
              &m
              , &job[i]
              , &sync[i]
              , [] (task *t) {
                  bsg_print_int(t->data[0]);
                  bsg_print_float(reinterpret_cast<float&>(t->data[1]));
              }
              , 1
              , 3.14159f);
      }

      // dispatch all jobs
      manager_dispatch_all(&m);

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
