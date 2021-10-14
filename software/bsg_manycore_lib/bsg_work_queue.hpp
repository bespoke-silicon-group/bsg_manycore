#pragma once
#include <atomic>
#include "bsg_mcs_mutex.h"
#include "bsg_manycore.hpp"

struct task {
    task *next;
    void (*func)();
};

struct task_queue {
    bsg_mcs_mutex_t    lock;
    std::atomic<task*> head; // one worker can pop
    std::atomic<task*> tail; // anyone can push
}

struct worker {
    worker *next_idle; // pointer to next idle worker
    worker *self; // globally addressable pointer to self
    task   *task; // set to next task to perform
};

struct worker_queue {
    bsg_mcs_mutex_t      lock;    
    std::atomic<worker*> head; // one can pop
    std::atomic<worker*> tail; // anyone can push
};

template <typename T>
static T atomic_load(volatile T *p)
{
    return *p;
}

/**
   Wait for work to become available
 */
static void worker_wait(worker_queue *wq
                        , worker *w
                        , task_queue *tq)
{
    // init
    bsg_mcs_mutex_node_t me, *g_me = bsg_tile_group_remote_ptr(__bsg_x, __bsg_y, &me);    
    worker *wg = bsg_tile_group_remote_ptr<worker>(__bsg_x, __bsg_y, w);
    w->self = wg;
    w->task = nullptr;
    // event loop
    while (true) {
        // acquire lock on worker queue
        bsg_mcs_mutex_acquire(&wq->lock, &me, &g_me);
        worker *old_tail = wq->tail.exchange(wg, std::memory_order_relaxed);
        if (old_tail != nullptr) {
            // update predecessor
            old_tail->next_idle = wg;
        } else {
            // update head
            wq->head.store(w, std::memory_order_relaxed);
        }
        // release the lock
        bsg_mcs_release(&wq->lock, &me, &g_me);

        // wait for a task
        while (atomic_load(&w->task));

        // wake up
        bsg_mcs_mutex_acquire(&wq->lock, me, g_me);
        task t = *(w->task);
        // is there a successor?
        if (w->next_idle != nullptr) {
            // is there a next task?
            if (task.next != nullptr) {
                // wake them up
                w->next_idle->task = task.next;
            } else {
                // update the head with your successor
                tq->head.store(w->next_idle, std::memory_order_relaxed);
            }
        } else {
            // set the head and tail to null
            tq->head.store(nullptr, std::memory_order_relaxed);
            tq->tail.store(nullptr, std::memory_order_relaxed);
        }
        bsg_mcs_mutex_release(&wq->lock, me, g_me);

        // exec task
        t.func();
    }
}

static void task_enqueue(task_queue *tq, task *t, worker_queue *wq)
{
    // add to tail    
    
}
