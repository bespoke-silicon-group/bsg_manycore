#pragma once
#include <atomic>
#include "bsg_manycore.hpp"
#include "bsg_manycore.h"

// helpful
template <typename T>
static T atomic_load(volatile T *v)
{
    return *v;
}

// Can live anywhere
struct task {    
    task  *next;
    void (*call)(task*);
    int   *done;
    int    data_words;
    int    data[1];
};

/**
 * Clear task of value
 */
static void task_clear(task *t)
{
    t->done = nullptr;
    t->call = nullptr;
    t->next = nullptr;
    t->data_words = 0;
}

// Must live in DMEM
struct worker {
    int     pending;    
    worker *next;    
    task    work;
};

struct task_queue;
// Must live in DMEM
struct manager {
    // manager:
    // 1. wait until not null
    // 2. move head to ready queue
    // 3. set head to null
    // 4. amoswap null with tail, save tail as tail of ready
    //
    // worker:
    // 1. old_tail = amoswap(&idle_tail, &self)
    // 2. if (old_tail == nullptr), head = &self
    // 3. wait until ready task
    //
    worker *idle_head;
    worker *ready_head;
    worker *ready_tail;
    // enqueud tasks
    // only manager reads/writes these
    task *pending_head;
    task *pending_tail;
    // task queue object
    task_queue *tq;
};

// Must live in DRAM
struct task_queue {
    std::atomic<worker*>  idle_tail; // only workers write this
    std::atomic<worker**> idle_head; // only manager sets this, worker read once
};

/**
 * Initialze a task queue, only the manager should call this function
 */
static void manager_init(manager *m, task_queue *tq)
{
    manager *self = bsg_tile_group_remote_pointer<manager>(__bsg_x, __bsg_y, m);
    m->idle_head = nullptr;
    m->ready_head = nullptr;
    m->ready_tail = nullptr;
    m->pending_head = nullptr;
    m->pending_tail = nullptr;

    tq->idle_head.store(&self->idle_head, std::memory_order_relaxed);
    m->tq = tq;
    return;
}

/**
 * Initialize a worker, enter main loop
 */
static void worker_init(worker *w, task_queue *tq)
{
    worker *self = bsg_tile_group_remote_pointer<worker>(__bsg_x, __bsg_y, w);
    worker **idle_head = tq->idle_head.load(std::memory_order_relaxed);
    
    while (true) {
        // zero-out
        task_clear(&w->work);
        w->next = nullptr;
        w->pending = 0;

        // add self to queue
        worker *tail = tq->idle_tail.exchange(self, std::memory_order_relaxed);

        // am I the head?
        if (tail == nullptr) {
            // update the manager's idle head
            *idle_head = self;
        } else {
            tail->next = self;
        }

        // wait for work
        // can use lbr here
        while (atomic_load(&w->pending) != 1);

        // do task
        w->work.call(&w->work);
        // notify done
        if (w->work.done != nullptr)
            *(w->work.done) = 1;
    }
}

/**
 * Enqueue a task as the manager
 */
static void manager_enqueue(manager *m, task *t)
{
    if (m->pending_tail != nullptr) {
        m->pending_tail->next = t;
        m->pending_tail = t;
    } else {
        m->pending_head = t;
        m->pending_tail = t;
    }
}


/**
 * Dispatch a task as the manager
 */
static void manager_dispatch_now(manager *m, task *t)
{
    // refill ready queue if necessary
    if (m->ready_head == nullptr) {
        // if there's no ready workers
        // wait for an idle worker to show up
        while (atomic_load(&m->idle_head) == nullptr);
        // move to ready queue
        m->ready_head = m->idle_head;
        m->idle_head = nullptr;
        // amoswap idle_tail with null, save as tail of ready queue
        // this will 'unlock' idle_head, after which the next idle worker will set it
        m->ready_tail = m->tq->idle_tail.exchange(nullptr, std::memory_order_relaxed);            
    }

    // dispatch next task to first ready
    worker *w = m->ready_head;
    worker *wn = atomic_load(&w->next);
        
    // make sure the above load happens, as it is remote        
    bsg_compiler_memory_barrier();

    // dispatch task to w
    w->work.call = t->call;
    w->work.done = t->done;

    // copy task data words
    for (int i = 0; i < t->data_words; i++)
        w->work.data[i] = t->data[i];

    // check for race condition where there is idle worker
    // adding themselves to ready queue, but ready_head
    // not updated yet.
    // hopefully this is very rare...
    if (w != m->ready_tail && wn == nullptr) {
        do {
            wn = atomic_load(&w->next);
        } while (wn == nullptr);
            
    }

    // notify task pending to worker
    w->pending = 1;
    m->ready_head = wn;
}

/**
 * Dispatch a task as the manager
 */
static void manager_dispatch(manager *m)
{
    // return if nothing to do
    if (m->pending_head != nullptr) {
        task *t = m->pending_head;
        m->pending_head = t->next;
        manager_dispatch_now(m, t);
    }
}


/**
 * Dispatch all enqueued tasks as the manager
 */
static void manager_dispatch_all(manager *m)
{
    while (m->pending_head != nullptr) {
        manager_dispatch(m);
    }
}

/////////////////////////
// Syntactic Sugar API //
/////////////////////////

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
