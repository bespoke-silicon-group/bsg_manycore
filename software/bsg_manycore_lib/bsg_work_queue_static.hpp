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

template <typename T>
static void wait_local_not_zero_asm(T *ptr)
{
    T tmp;
    __asm__ __volatile__("2: lr.w %0, %1\n\t"
                         "bnez    %0, 1f\n\t"
                         "lr.w.aq %0, %1\n\t"
                         "bnez    %0, 2b\n\t"
                         "1:\n\t" : "=r" (tmp) : "A" (*ptr));
    return;
}

/**
 * This must live in DRAM
 */
template <typename LAMBDA>
struct task_queue {
public:
    /**
     * Can live anywhere
     */
    struct task {
        LAMBDA lambda;
        task    *next;
        task(){}
        task(LAMBDA l) : lambda(l){}
        void clear() {
            next = nullptr;
        }
    };

    /**
     * Must live in DMEM
     */
    struct worker {
        int  pending;
        int     done;
        worker *next;
        task    work;
        void init(task_queue *tq) {
            worker *self = bsg_tile_group_remote_pointer<worker>(__bsg_x, __bsg_y, this);
            worker **idle_head = tq->idle_head.load(std::memory_order_relaxed);
            this->done = 0;
            while (true) {
                // zero-out
                this->work.clear();
                this->next = nullptr;
                this->pending = 0;

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
                wait_local_not_zero_asm(&this->pending);

                if (this->done)
                    return;

                // do task
                this->work.lambda();
            }
        }
    };

    /**
     * Must live in DMEM
     */
    struct manager {
        // idle workers
        worker *idle_head;
        // ready workers
        worker *ready_head;
        worker *ready_tail;
        // pending tasks
        task *pending_head;
        task *pending_tail;
        // task queue
        task_queue *tq;
        // initialize
        void init(task_queue *tq) {
            manager *self = bsg_tile_group_remote_pointer<manager>(__bsg_x, __bsg_y, this);
            this->idle_head = nullptr;
            this->ready_head = nullptr;
            this->ready_tail = nullptr;
            this->pending_head = nullptr;
            this->pending_tail = nullptr;

            tq->idle_head.store(&self->idle_head, std::memory_order_relaxed);
            this->tq = tq;
            return;
        }
    private:
        int update_ready() {
            // refill ready queue if necessary
            if (this->ready_head == nullptr) {
                // return if there's no idle
                if (this->idle_head == nullptr)
                    return 0;

                // move to ready queue
                this->ready_head = this->idle_head;
                this->idle_head = nullptr;
                // amoswap idle_tail with null, save as tail of ready queue
                // this will 'unlock' idle_head, after which the next idle worker will set it
                this->ready_tail = this->tq->idle_tail.exchange(nullptr, std::memory_order_relaxed);
            }
            return 1;
        }

    public:
        // dispatch a task now, do not block on idle worker
        int try_release_now() {
            // update ready queue
            if (!update_ready())
                return 0;

            // dispatch next task to first ready
            worker *w = this->ready_head;
            worker *wn = atomic_load(&w->next);

            // make sure the above load happens, as it is remote
            bsg_compiler_memory_barrier();

            // check for race condition where there is idle worker
            // adding themselves to ready queue, but ready_head
            // not updated yet.
            // hopefully this is very rare...
            if (w != this->ready_tail && wn == nullptr) {
                do {
                    wn = atomic_load(&w->next);
                } while (wn == nullptr);

            }

            // notify task pending to worker
            w->done  = 1;
            w->pending = 1;
            this->ready_head = wn;
            return 1;
        }

        // dispatch a task now, do not block on idle worker
        int try_dispatch_now(task *t) {
            // update ready queue
            if (!update_ready())
                return 0;

            // dispatch next task to first ready
            worker *w = this->ready_head;
            worker *wn = atomic_load(&w->next);

            // make sure the above load happens, as it is remote
            bsg_compiler_memory_barrier();

            // dispatch task to w
            w->work.lambda = t->lambda;

            // check for race condition where there is idle worker
            // adding themselves to ready queue, but ready_head
            // not updated yet.
            // hopefully this is very rare...
            if (w != this->ready_tail && wn == nullptr) {
                do {
                    wn = atomic_load(&w->next);
                } while (wn == nullptr);

            }

            // notify task pending to worker
            w->pending = 1;
            this->ready_head = wn;
            return 1;
        }

        // dispatch a task now, block until worker available
        void dispatch_now(task *t) {
            // refill ready queue if necessary
            if (this->ready_head == nullptr) {
                // if there's no ready workers
                // wait for an idle worker to show up
                wait_local_not_zero_asm(&this->idle_head);
            }
            try_dispatch_now(t);
        }

        // release a worker, block until worker is released
        void release_now() {
            // refill ready queue if necessary
            if (this->ready_head == nullptr) {
                // if there's no ready workers
                // wait for an idle worker to show up
                wait_local_not_zero_asm(&this->idle_head);
            }
            try_release_now();
        }
    };
    std::atomic<worker*>  idle_tail; // only workers write this
    std::atomic<worker**> idle_head; // only manager sets this, worker read once
};