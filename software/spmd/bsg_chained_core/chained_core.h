#ifndef __CHAINED_CORES__
#define __CHAINED_CORES__

//the data structure that will pass through the cores.
typedef struct __attribute__((__packed__))  chained_tag_def {
    // the actual data value;
    unsigned char   value;
    // the round number of the data: LIMIT: 256 rounds
    unsigned char   rounds;
    // number of the cores that this pack have passed
    // when data passed each core, this value will be added by the core id
    unsigned short  cores;
} chained_tag_s;

typedef union tag_data_def{
    unsigned int    data;
    chained_tag_s   tag;
}tag_data_s;

/////////////////////////////////////////////////////////////////////////////
// Declare the function array
typedef void (*proc_func_ptr) (tag_data_s *, volatile tag_data_s*, int, int, int);

//different process task configurations
//
// ALL_ZERO_FUNCS:   all of the processor do nothing
// ALL_COPY_FUNCS:   all of the processor just copy local data to the remote

typedef enum {  eALL_ZERO_FUNCS,    \
                eALL_PASS_FUNCS,    \
                eONE_COPY_FUNCS,    \
                eALL_TAG_PASS_FUNCS \
              } config_enum;

void init_func_array( config_enum );

//////////////////////////////////////////////////////////////////////////////////////////
//the process will wait until the specified memory address was written with specific value
inline void spin_cond(int * ptr,  int cond ) {
    int tmp;
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return ;  //the data is ready, TODO:shall we clear the reservation?
        else{
            tmp = bsg_lr_aq( ptr );  //stall until somebody clear the reservation
            if( tmp == cond ) return ; //return if data is expected, otherwise retry
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////////
//A delay function
inline void spin_uncond(int cycles){
    do{
     __asm__ __volatile__ ("nop"  );
    }while( ( cycles --) > 0);
}

//////////////////////////////////////////////////////////////////////////////////////////
//print buffer content
inline void print_buff( tag_data_s * pData, int len){
    for( int i=0; i< len ; i ++ ){
        bsg_remote_ptr_io_store(0, &(pData[i].data), pData[i].data);
    }
}

#include "chained_config.h"
#endif
