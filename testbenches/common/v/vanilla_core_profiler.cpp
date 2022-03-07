#include <cstdio>
#include <cstdlib>
#include <memory>

namespace bsg_vanilla_core_profiler
{
    int is_init = 0;
    int is_exit = 0;
    int trace_file = -1;
}
extern "C"
{
    using namespace bsg_vanilla_core_profiler;
    void bsg_vanilla_core_profiler_init(
        int _trace_file
        ) {
        if (!is_init) {
            trace_file = _trace_file;
            is_init = 1;
        }
    }

    void bsg_vanilla_core_profiler_exit() {
        return;
    }

    int bsg_vanilla_core_profiler_is_init() {
        return is_init;
    }

    int bsg_vanilla_core_profiler_is_exit() {
        return is_exit;
    }

    int  bsg_vanilla_core_profiler_trace_fd() {
        return trace_file;
    }
}
