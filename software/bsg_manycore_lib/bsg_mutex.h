//====================================================================
// bsg_mutex.h
// 03/02/2019, shawnless.xie@gmail.com
//====================================================================
// The mutex implementation in manycore
//
// Repurpose amoswap.w instructions pair
//
// swap.aq: lock the address, the returned value indicates success or failure 
//          return 0 :  sucess
//          return 1 :  fail.
//
// swap.rl: release the lock, no return result. 
#ifndef  BSG_MUTEX_H_
#define  BSG_MUTEX_H_

typedef unsigned int volatile bsg_mutex     ;
typedef bsg_remote_int_ptr    bsg_mutex_ptr ;

typedef enum { bsg_mutex_lock_fail   =1,
               bsg_mutex_lock_success=0
             } bsg_mutex_status ;

//   return 1 if failed.
//   return 0 if success
static int  inline bsg_mutex_try_lock(    bsg_mutex_ptr p_mutex );
static void inline bsg_mutex_lock(        bsg_mutex_ptr p_mutex );
static void inline bsg_mutex_unlock(      bsg_mutex_ptr  p_mutex );
static void inline bsg_atomic_inc ( bsg_mutex_ptr p_mutex, bsg_remote_int_ptr p_value);
//--------------------------------------------------------------------------------
// wait until the specified memory address was written with specific value
static int inline bsg_wait_local_int(int * ptr,  int cond ) {
    int tmp;
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return tmp;  //the data is ready
        else{
            tmp = bsg_lr_aq( ptr );    //stall until somebody clear the reservation
            if( tmp == cond ) return tmp; //return if data is expected, otherwise retry
        }
    }
}
//====================================================================
//
static int inline bsg_mutex_try_lock( bsg_mutex_ptr p_mutex ){

    bsg_mutex_status result = bsg_mutex_lock_fail;

    unsigned int mutex_addr = (unsigned int) ( p_mutex );
    unsigned int swap_val = 1;

    asm volatile ("amoswap.w.aq %[result], %[swap_val], 0(%[addr]);"  \
                      : [result] "=r"  (result             ) \
                      : [addr]   "r"   (mutex_addr         ), [swap_val] "r" (swap_val) \
                     );

    return result;
}

static void inline bsg_mutex_lock( bsg_mutex_ptr  p_mutex ){
    int result = bsg_mutex_lock_fail;
    do{
       result =  bsg_mutex_try_lock( p_mutex );

    }while( result == bsg_mutex_lock_fail);
}

static void inline bsg_mutex_unlock( bsg_mutex_ptr  p_mutex ){


    unsigned int mutex_addr = (unsigned int) ( p_mutex );

    asm volatile ("amoswap.w.rl x0, x0, 0(%[addr]);"   \
                      :                                                 \
                      :[addr]     "r"       (mutex_addr         )       \
                );
}

static void inline bsg_atomic_inc( bsg_mutex_ptr  p_mutex,  bsg_remote_int_ptr p_value){

    int volatile value;

    bsg_mutex_lock( p_mutex );  // ------>

    value = *p_value  ;
    value = value + 1 ;
    *p_value = value  ;

    bsg_mutex_unlock( p_mutex ); //<------
}

#endif
