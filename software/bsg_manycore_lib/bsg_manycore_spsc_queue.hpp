
#ifndef _BSG_MANYCORE_SPSC_QUEUE_HPP
#define _BSG_MANYCORE_SPSC_QUEUE_HPP

#include <bsg_manycore_atomic.h>

template <typename T, int S>
class bsg_manycore_spsc_queue_recv {
private:
    volatile T *buffer;
    volatile int *count;
    volatile int rptr;

public:
    bsg_manycore_spsc_queue_recv(T *buffer, int *count) 
        : buffer(buffer), count(count), rptr(0) { };

    bool is_empty(void)
    {
        return *count == 0;
    }

    bool try_recv(T *data)
    {
        if (is_empty())
        {
            return false;
        }

        bsg_compiler_memory_barrier();
        *data = buffer[rptr];
        bsg_compiler_memory_barrier();
        // Probably faster than modulo, but should see if compiler
        //   optimizes...
        if (++rptr == S)
        {
            rptr = 0;
        }
        bsg_compiler_memory_barrier();
        bsg_amoadd(count, -1);

        return true;
    }

    // TODO: Add timeout?
    T recv(void)
    {
        T data;
        while (1)
        {
            if (try_recv(&data)) break;
        }

        return data;
    }
};

template <typename T, int S>
class bsg_manycore_spsc_queue_send {
private:
    volatile T *buffer;
    volatile int *count;
    volatile int wptr;

public:
    bsg_manycore_spsc_queue_send(T *buffer, int *count) 
        : buffer(buffer), count(count), wptr(0) { };

    bool is_full(void)
    {
        return (*count == S);
    }

    bool try_send(T data)
    {
        if (is_full()) return false;

        buffer[wptr] = data;
        bsg_compiler_memory_barrier();
        // Probably faster than modulo, but should see if compiler
        //   optimizes...
        if (++wptr == S)
        {
            wptr = 0;
        }
        bsg_compiler_memory_barrier();
        bsg_amoadd(count, 1);

        return true;
    }

    // TODO: Add timeout?
    void send(T data)
    {
        while (1)
        {
            if (try_send(data)) break;
        }
    }
};

#endif

