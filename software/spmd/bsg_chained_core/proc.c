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
void pass_proc( tag_data_s *local_ptr, volatile tag_data_s *remote_ptr, \
                int num, int rounds, int id){
    int i;
    tag_data_s tmp0,tmp1;
    //software pipeline the operation so to break the load data dependence
    for( i=0; i< num; i= i+2 ){
        tmp0 =   local_ptr[i ];
        tmp1 =   local_ptr[i+1];
        remote_ptr[i]   = tmp0;
        remote_ptr[i+1] = tmp1;
    }
    //move the last elements
    if( num & 0x1 ) remote_ptr[num-1] = local_ptr[num-1];
}

/////////////////////////////////////////////////////////////////////////////
// tag the data, and pass the local data to the remote
// compute/mem = 1:1
void tag_pass_proc( tag_data_s *local_ptr, volatile tag_data_s *remote_ptr, \
                    int num, int rounds,int id){

    int i;
    tag_data_s tmp0,tmp1;
    //software pipeline the operation so to break the load data dependence
    for( i=0; i< num ; i= i+2 ){
        tmp0 =   local_ptr[i ];
        tmp1 =   local_ptr[i+1];

        tmp0.tag.cores += id;
        tmp0.tag.rounds = rounds;

        tmp1.tag.cores += id;
        tmp1.tag.rounds = rounds;

        remote_ptr[i]   = tmp0;
        remote_ptr[i+1] = tmp1;
    }
    //move the last elements
    if( num & 0x1 ) {
        local_ptr [num-1].tag.cores += id;
        local_ptr [num-1].tag.rounds = rounds;

        remote_ptr[num-1] = local_ptr[num-1];
    }
}

/////////////////////////////////////////////////////////////////////////////
// copy local data to the local memory and pass the data to the remote
// compute/mem = 0:1
static tag_data_s local_buffer[BUF_LEN];
void copy_proc( tag_data_s *local_ptr, volatile tag_data_s *remote_ptr, \
                int num,int rounds, int id){
    int i;
    for( i=0; i< num; i++ ) {
        local_buffer[i] = local_ptr[i];
    }
   pass_proc( local_ptr, remote_ptr, num, rounds, id);
}

//initialize the function array with different configurations
void init_func_array(config_enum config){
    int i;

    switch( config) {
        case( eALL_PASS_FUNCS ):
            for( i=0; i< bsg_num_tiles-1; i++) func_array[i] = pass_proc;
            break;
        case( eALL_TAG_PASS_FUNCS ):
            for( i=0; i< bsg_num_tiles-1; i++) func_array[i] = tag_pass_proc;
            break;
        case( eONE_COPY_FUNCS ):
            for( i=0; i< bsg_num_tiles-1; i++) func_array[i] = pass_proc;
            func_array[1] = copy_proc;
            break;
        default:
            break;
    }
}
