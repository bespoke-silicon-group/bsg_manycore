#pragma once
#include <atomic>
#include "bsg_manycore.h"

typedef struct bsg_mutex_node {
    volatile struct bsg_mutex_node* next;
    volatile int               locked;
} bsg_mutex_node_t;

/**
 * This object must live in global memory (DRAM).
 */
//typedef struct bsg_mutex_node* bsg_mutex2_t;
typedef struct std::atomic<bsg_mutex_node*> bsg_mutex2_t;

/**
 * Acquires the lock.
 * 
 * Attempts to acquire the lock from mtx with an amoswap and if that fails
 * this function adds lcl to the queue and waits to be woken up.
 */
static void bsg_mutex2_acquire(bsg_mutex2_t *mtx, bsg_mutex_node_t *lcl)
{
    bsg_mutex_node_t *pred; // who's before us

    lcl->next = nullptr;
    lcl->locked = 1;
    pred = mtx->exchange(lcl, std::memory_order_acquire);
    // was there someone before us in line?
    if (pred != nullptr) {
        // tell our predecessor to notify us when done
        pred->next = lcl;
        // spin on our locked variable
        while (lcl->locked);
    }
}

/**
 * Releases the lock.
 *
 * Releases the lock by waking its successor. Also attempts to remove self from the global queue
 * if it has no successor.
 */
static void bsg_mutex2_release(bsg_mutex2_t *mtx, bsg_mutex_node_t *lcl)
{
    // successor exists, unlock and return
    if (lcl->next != nullptr) {
        // fence and release
        bsg_fence();
        lcl->next->locked = 0;
        return;
    }

    // no successor, head still points to us
    // attempt to swap out head with null
    bsg_mutex_node_t *vic_tail;
    vic_tail = mtx->exchange(nullptr, std::memory_order_release);
    if (vic_tail == lcl) {
        // there's still no successor
        return;
    }

    // a successor added itself to the queue
    // we have to put it back
    // wait for next pointer to point to some head of our victims
    while (lcl->next == nullptr);

    bsg_mutex_node_t *usurper;
    usurper = mtx->exchange(vic_tail, std::memory_order_release);

    // did someone else get in line in the mean time?
    if (usurper == nullptr) {
        lcl->next->locked = 0;
        return;
    }

    // add victims behind usurper
    usurper->next = lcl->next;
}
