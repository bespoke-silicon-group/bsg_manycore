/******************************************************************************
 *  Different processs with different computation/memory operation ratios 
 *
*****************************************************************************/
#include "bsg_manycore.h"
#include "chained_core.h"

proc_func_ptr func_array[ bsg_num_tiles ] = { 0 };

/////////////////////////////////////////////////////////////////////////////
// Just passt the local data to the remote
// compute/mem = 1:1
void gen_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    do{
        for( i=0; i< num; i++ )     remote_ptr[i] = local_ptr[i];
    }while(1);
}

void asm_gen_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int *s_ptr = local_ptr; 
    volatile int *d_ptr = remote_ptr;
    while( 1 ){
        __asm__ __volatile__ ("lw t0, 0(%0)" ::"r"( s_ptr ) ); 
        __asm__ __volatile__ ("lw t1, 4(%0)" ::"r"( s_ptr ) ); 
        __asm__ __volatile__ ("lw t2, 8(%0)" ::"r"( s_ptr ) ); 
        __asm__ __volatile__ ("lw t3, 12(%0)"::"r"( s_ptr ) ); 
    
        __asm__ __volatile__ ("sw t0, 0(%0)" ::"r"( d_ptr ) ); 
        __asm__ __volatile__ ("sw t1, 4(%0)" ::"r"( d_ptr ) ); 
        __asm__ __volatile__ ("sw t2, 8(%0)" ::"r"( d_ptr ) ); 
        __asm__ __volatile__ ("sw t3, 12(%0)"::"r"( d_ptr ) ); 
       }
}

/////////////////////////////////////////////////////////////////////////////
// Just passt the local data to the remote
// compute/mem = 0:1

int local_buffer[BUF_LEN];
void add_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    for( i=0; i< num; i++ ) {
        local_buffer[i] = local_ptr[i] + local_buffer[i];
    }
   for( i=0; i< num; i++ )     remote_ptr[i] = local_buffer[i];
}

void copy_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    for( i=0; i< num; i++ ) {
        local_buffer[i] = local_ptr[i] ;
    }
}

void asm_copy_proc( int *local_ptr, volatile int *remote_ptr, int num){
    int i;
    for( i=0; i<num; i=i+4) {
        __asm__ ("lw t0, 0(%0)" ::"r"( local_ptr  ) ); 
        __asm__ ("lw t1, 4(%0)" ::"r"( local_ptr  ) ); 
        __asm__ ("lw t2, 8(%0)" ::"r"( local_ptr  ) ); 
        __asm__ ("lw t3, 12(%0)"::"r"( local_ptr  ) ); 

        __asm__ ("sw t0, 0(%0)" ::"r"( local_buffer ) ); 
        __asm__ ("sw t1, 4(%0)" ::"r"( local_buffer ) ); 
        //__asm__ ("sw t2, 8(%0)" ::"r"( local_buffer ) ); 
        //__asm__ ("sw t3, 12(%0)"::"r"( local_buffer ) ); 
    }
}

//initialize the function array with different configurations
void init_func_array(config_enum config){
    int i;
    func_array[0] = asm_gen_proc;
    func_array[1] = asm_copy_proc;
    //func_array[0] = gen_proc;
    //func_array[1] = copy_proc;
}
