#ifndef __CHAINED_CORES__
#define __CHAINED_CORES__

#include "chained_config.h"

/////////////////////////////////////////////////////////////////////////////
// Declare the function array 
typedef void (*proc_func_ptr) (int *, volatile int*, int); 

//different process task configurations
// 
// ALL_ZERO_FUNCS:   all of the processor do nothing
// ALL_COPY_FUNCS:   all of the processor just copy local data to the remote

typedef enum {eALL_ZERO_FUNCS, eALL_PASS_FUNCS, eONE_COPY_FUNCS} config_enum;

void init_func_array( config_enum );

#endif
