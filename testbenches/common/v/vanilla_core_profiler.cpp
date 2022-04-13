#include <map>
#include <vector>
#include <sstream>
#include <string>
#include <cstdio>
#include <cstdlib>
#include "profiler.hpp"

class vanilla_core_profiler : public bsg_profiler::profiler {
public:
    vanilla_core_profiler(): bsg_profiler::profiler (){}
};

vanilla_core_profiler bsg_vanilla_core_profiler;

DEFINE_PROFILER(bsg_vanilla_core_profiler);


