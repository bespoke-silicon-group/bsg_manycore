//====================================================================
// bsg_mutex.h
// 03/07/2018, shawnless.xie@gmail.com
//====================================================================
// The mutex implementation in manycore
//
// Using amoswap.w instructions pair
//
// swap.aq.success: return the loaded value
// swap.aq.fail   : return the original value
// swap.rl.success: return the loaded value
// swap.rl.fail   : return the original value
#ifndef  BSG_MUTEX_H_
#define  BSG_MUTEX_H_

typedef unsigned int volatile bsg_mutex     ;
typedef bsg_remote_int_ptr    bsg_mutex_ptr ;

typedef enum { bsg_mutex_locked     =1,
               bsg_mutex_unlocked   =0
             } bsg_mutex_status ;

//   return 0 if failed.
//   return 1 if success
//
//   Status             action          results
//   --------------------------------------------------
//   locked by #A       A try lock      fail
//   locked by #A       B try lock      fail
//   unlocked           A try lock      success
int  inline bsg_mutex_try_lock(    bsg_mutex_ptr p_mutex );

void inline bsg_mutex_lock(        bsg_mutex_ptr p_mutex );

//   return 0 if failed.
//   return 1 if success
//
//   Status             action          results
//   --------------------------------------------------
//   locked by #A       A try unlock    success
//   locked by #B       A try unlock    fail
//   unlocked           A try unlock    fail
int  inline bsg_mutex_unlock(      bsg_mutex_ptr  p_mutex );

void inline bsg_atomic_add ( bsg_mutex_ptr p_mutex, bsg_remote_int_ptr p_value);

// wait until the specified memory address was written with specific value
int bsg_wait_local_int(int * ptr,  int cond ) {
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
int inline bsg_mutex_try_lock( bsg_mutex_ptr p_mutex ){

    bsg_mutex_status old_status = bsg_mutex_unlocked;

    unsigned int mutex_addr = (unsigned int) ( p_mutex );

    asm volatile ("amoswap.w.aq %[old_stat], %[new_stat], 0(%[addr]);"  \
                      : [old_stat] "=r"  (old_status         )              \
                      : [new_stat] "r"   (bsg_mutex_locked   )              \
                       ,[addr]     "r"   (mutex_addr         )              \
                     );

    if( old_status == bsg_mutex_locked ) return 0;
    else                                 return 1;
}

void inline bsg_mutex_lock( bsg_mutex_ptr  p_mutex ){
    int is_locked = 0;
    do{
       is_locked =  bsg_mutex_try_lock( p_mutex );

    }while( is_locked == 0);
}

int inline bsg_mutex_unlock( bsg_mutex_ptr  p_mutex ){

    bsg_mutex_status old_status = bsg_mutex_unlocked;

    unsigned int mutex_addr = (unsigned int) ( p_mutex );

    asm volatile ("amoswap.w.rl %[old_stat], %[new_stat], 0(%[addr]);"   \
                      :[old_stat] "=r"      (old_status         )        \
                      :[new_stat] "r"       (bsg_mutex_unlocked )        \
                      ,[addr]     "r"       (mutex_addr         )        \
                );
   //unlock should always success
   if( old_status == bsg_mutex_unlocked )  return 0;
   else                                    return 1;

}

void inline bsg_atomic_add( bsg_mutex_ptr  p_mutex,  bsg_remote_int_ptr p_value){

    int volatile value;

    bsg_mutex_lock( p_mutex );  // ------>

    value = *p_value  ;
    value = value + 1 ;
    *p_value = value  ;

    bsg_mutex_unlock( p_mutex ); //<------
}

#endif
