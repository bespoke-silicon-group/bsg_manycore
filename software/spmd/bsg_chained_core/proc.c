/******************************************************************************
 *  Different processs with different computation/memory operation ratios
 *
*****************************************************************************/
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "chained_core.h"

proc_func_ptr func_array[ bsg_num_tiles ] = { 0 };

/////////////////////////////////////////////////////////////////////////////
// Just passt the local data to the remote
// compute/mem = 1:1
void pass_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    int tmp0,tmp1;
    //software pipeline the operation so to break the load data dependence
    for( i=0; i< (num/2); i= i+2 ){
        tmp0 =   local_ptr[i ];
        tmp1 =   local_ptr[i+1];
        remote_ptr[i]   = tmp0;
        remote_ptr[i+1] = tmp1;
    }
    //move the last elements
    if( num & 0x1 ) remote_ptr[num-1] = local_ptr[num-1];
}

/////////////////////////////////////////////////////////////////////////////
// Just passt the local data to the remote
// compute/mem = 0:1
static int local_buffer[BUF_LEN];
void copy_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    for( i=0; i< num; i++ ) {
        local_buffer[i] = local_ptr[i];
    }
   pass_proc( local_ptr, remote_ptr, num);
}

//initialize the function array with different configurations
void init_func_array(config_enum config){
    int i;

    switch( config) {
        case( eALL_PASS_FUNCS ):
            for( i=0; i< bsg_num_tiles-1; i++) func_array[i] = pass_proc;
            break;
        case( eONE_COPY_FUNCS ):
            for( i=0; i< bsg_num_tiles-1; i++) func_array[i] = pass_proc;
            func_array[1] = copy_proc;
            break;
        default:
            break;
    }
}
