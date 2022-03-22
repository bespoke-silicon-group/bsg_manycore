#pragma once
#include <mutex>
namespace bsg_profiler {
class profiler {
public:
    // constructors
    profiler()
        : is_exit(0)
        , trace_file(-1) {
    }

    // members
    int is_init;
    int is_exit;
    int trace_file;

    std::mutex mtx;
};
}

#define PROFILER_LOCK_FUNC(profiler_name)               \
    extern "C" void profiler_name ##_lock() {           \
        profiler_name.mtx.lock();                       \
    }

#define PROFILER_UNLOCK_FUNC(profiler_name)             \
    extern "C" void profiler_name ##_unlock() {         \
        profiler_name.mtx.unlock();                     \
    }

#define PROFILER_INIT_FUNC(profiler_name)               \
    extern "C" void profiler_name ## _init(             \
        int _trace_file                                 \
        ) {                                             \
        if (profiler_name.is_init == 0) {               \
            profiler_name.trace_file = _trace_file;     \
        }                                               \
    }

#define PROFILER_EXIT_FUNC(profiler_name)            \
    extern "C" void profiler_name ##_exit() {        \
        profiler_name.is_exit = 1;                   \
        return;                                      \
    }

#define PROFILER_IS_INIT_FUNC(profiler_name)        \
    extern "C" int profiler_name ## _is_init() {    \
        return profiler_name.is_init;               \
    }

#define PROFILER_IS_EXIT_FUNC(profiler_name)        \
    extern "C" int profiler_name ##_is_exit() {     \
        return profiler_name.is_exit;               \
    }

#define PROFILER_TRACE_FD_FUNC(profiler_name)           \
    extern "C" int profiler_name ##_trace_fd() {        \
        return profiler_name.trace_file;                \
    }

#define DEFINE_PROFILER(profiler_name)          \
    PROFILER_INIT_FUNC(profiler_name)           \
    PROFILER_EXIT_FUNC(profiler_name)           \
    PROFILER_IS_INIT_FUNC(profiler_name)        \
    PROFILER_IS_EXIT_FUNC(profiler_name)        \
    PROFILER_TRACE_FD_FUNC(profiler_name)       \
    PROFILER_LOCK_FUNC(profiler_name)           \
    PROFILER_UNLOCK_FUNC(profiler_name)
