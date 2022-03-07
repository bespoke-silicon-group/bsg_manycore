#pragma once
namespace bsg_profiler {
class profiler {
public:
    // constructors
    profiler()
        : is_exit(0)
        , trace_file(-1) {
    }

    // members
    int is_exit;
    int trace_file;
};
}

#define PROFILER_INIT_FUNC(profiler_name)               \
    extern "C" void profiler_name ## _init(             \
        int _trace_file                                 \
        ) {                                             \
        if (profiler_name == nullptr) {                 \
            profiler_name = new bsg_profiler::profiler; \
            profiler_name->trace_file = _trace_file;    \
        }                                               \
    }

#define PROFILER_EXIT_FUNC(profiler_name)            \
    extern "C" void profiler_name ##_exit() {        \
        return;                                      \
    }

#define PROFILER_IS_INIT_FUNC(profiler_name)        \
    extern "C" int profiler_name ## _is_init() {    \
        return (profiler_name != nullptr);          \
    }

#define PROFILER_IS_EXIT_FUNC(profiler_name)        \
    extern "C" int profiler_name ##_is_exit() {     \
        return profiler_name->is_exit;              \
    }

#define PROFILER_TRACE_FD_FUNC(profiler_name)           \
    extern "C" int profiler_name ##_trace_fd() {        \
        return profiler_name->trace_file;               \
    }

#define DEFINE_PROFILER(profiler_name)          \
    PROFILER_INIT_FUNC(profiler_name)           \
    PROFILER_EXIT_FUNC(profiler_name)           \
    PROFILER_IS_INIT_FUNC(profiler_name)        \
    PROFILER_IS_EXIT_FUNC(profiler_name)        \
    PROFILER_TRACE_FD_FUNC(profiler_name)
