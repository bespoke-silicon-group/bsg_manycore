#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BUFF_LEN    8
int int_array0[BUFF_LEN] = { 0x10000000, 0x20000000, 0x30000000, 0x40000000,
                              0x50000000, 0x60000000, 0x70000000, 0x80000000} ;
int int_array1[BUFF_LEN] = { 0x10000000>>1, 0x20000000>>1, 0x30000000>>1, 0x40000000>>1,
                              0x50000000>>1, 0x60000000>>1, 0x70000000>>1, ((int)0x80000000)>>1} ;
int int_local[BUFF_LEN]={0};

short short_array0[BUFF_LEN] = { 0x1000, 0x2000, 0x3000, 0x4000,
                                 0x5000, 0x6000, 0x7000, 0x8000} ;
short short_array1[BUFF_LEN] = { 0x1000>>1, 0x2000>>1, 0x3000>>1, 0x4000>>1,
                                 0x5000>>1, 0x6000>>1, 0x7000>>1, ((short)0x8000)>>1} ;
short short_local[BUFF_LEN]={0};

char  char_array0[BUFF_LEN] = { 0x10, 0x20, 0x30, 0x40,
                                 0x50, 0x60, 0x70, 0x80} ;
char  char_array1[BUFF_LEN] = { 0x10>>1, 0x20>>1, 0x30>>1, 0x40>>1,
                                 0x50>>1, 0x60>>1, 0x70>>1, ((char)0x80)>>1} ;
char  char_local[BUFF_LEN]={0};

//code runs on processor 0
void proc0(void){
}

//remote load
#define REMOTE_LOAD_GEN( DATA_TYPE, X, Y )                            \
void remote_load_##DATA_TYPE##_##X##_##Y(void){                      \
    DATA_TYPE tmp0,tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;    \
                                                                                \
    tmp0 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[0])   );          \
    tmp1 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[1])   );          \
    tmp2 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[2])   );          \
    tmp3 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[3])   );          \
    tmp4 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[4])   );          \
    tmp5 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[5])   );          \
    tmp6 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[6])   );          \
    tmp7 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[7])   );          \
                                                                                \
    DATA_TYPE##_local[0]   =  tmp0;                                                    \
    DATA_TYPE##_local[1]   =  tmp1;                                                    \
    DATA_TYPE##_local[2]   =  tmp2;                                                    \
    DATA_TYPE##_local[3]   =  tmp3;                                                    \
    DATA_TYPE##_local[4]   =  tmp4;                                                    \
    DATA_TYPE##_local[5]   =  tmp5;                                                    \
    DATA_TYPE##_local[6]   =  tmp6;                                                    \
    DATA_TYPE##_local[7]   =  tmp7;                                                    \
}


#define CHECK_GEN( DATA_TYPE )                                              \
int check_##DATA_TYPE(void){                                          \
    for( int i=0; i< BUFF_LEN; i++){                                        \
        if( DATA_TYPE##_local[i] != (DATA_TYPE##_array1[i] << 1) )          \
            return ( i+1) ;                                                 \
    }                                                                       \
    return 0;                                                               \
}

#define CHECK_SELF_GEN( DATA_TYPE )                                              \
inline int check_self_##DATA_TYPE(void){                                          \
    for( int i=0; i< BUFF_LEN; i++){                                        \
        if( DATA_TYPE##_local[i] != (DATA_TYPE##_array0[i] ) )              \
            return ( i+1) ;                                                 \
    }                                                                       \
    return 0;                                                               \
}

//remote store & load
#define REMOTE_STORE_LOAD_GEN( DATA_TYPE, X, Y )                            \
inline void remote_store_load_##DATA_TYPE##_##X##_##Y(void){                      \
    DATA_TYPE tmp0,tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7;    \
                                                                \
    tmp4 = DATA_TYPE##_array1[ 4 ]  ;                           \
    tmp5 = DATA_TYPE##_array1[ 5 ]  ;                           \
    tmp6 = DATA_TYPE##_array1[ 6 ]  ;                           \
    tmp7 = DATA_TYPE##_array1[ 7 ]  ;                           \
                                                                \
    *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[0])   )        = tmp4 ;          \
    tmp0 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[0])   );                   \
                                                                                                \
    *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[1])   )        = tmp5 ;          \
    tmp1 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[1])   );                   \
                                                                                               \
    *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[2])   )        = tmp6 ;          \
    tmp2 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[2])   );                   \
                                                                                               \
    *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[3])   )        = tmp7 ;          \
    tmp3 = *( ( DATA_TYPE *) bsg_remote_ptr(X,Y, &DATA_TYPE##_array0[3])   );                   \
                                                                                        \
    DATA_TYPE##_local[0]   =  tmp0;                                                    \
    DATA_TYPE##_local[1]   =  tmp1;                                                    \
    DATA_TYPE##_local[2]   =  tmp2;                                                    \
    DATA_TYPE##_local[3]   =  tmp3;                                                    \
}

#define CHECK_STORE_LOAD_GEN( DATA_TYPE )                                              \
int check_store_load_##DATA_TYPE( void ) {                                        \
    if( DATA_TYPE##_local[0]  != DATA_TYPE##_array1[ 4 ] ) return  1;                     \
    if( DATA_TYPE##_local[1]  != DATA_TYPE##_array1[ 5 ] ) return  2;                     \
    if( DATA_TYPE##_local[2]  != DATA_TYPE##_array1[ 6 ] ) return  3;                     \
    if( DATA_TYPE##_local[3]  != DATA_TYPE##_array1[ 7 ] ) return  4;                     \
    return 0;                                                                             \
}

////////////////////////////////////////////////////////////////////
// Generate the load and check funcitons.

REMOTE_LOAD_GEN( int, 0, 0 )
CHECK_GEN( int )

REMOTE_LOAD_GEN( short,0,0 )
CHECK_GEN( short )

REMOTE_LOAD_GEN( char, 0,0)
CHECK_GEN( char )

REMOTE_STORE_LOAD_GEN( int,0,0)
CHECK_STORE_LOAD_GEN( int)

REMOTE_LOAD_GEN( int,1,0)
CHECK_SELF_GEN( int )
//code runs on processor 1
void proc1(void){

    remote_load_int_0_0();
    int error = check_int();

    if( error == 0) bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, 0x0 );
    else              bsg_fail();

    remote_load_short_0_0();
    error = check_short();

    if( error == 0) bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, 0x1 );
    else              bsg_fail();

    remote_load_char_0_0();
    error = check_char();

    if( error == 0) {
        bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, 0x2 );
    } else {
        bsg_fail();
    }

    remote_store_load_int_0_0();
    error = check_store_load_int();

    if( error == 0) {
        bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, 0x3 );
    } else {
        bsg_fail();
    }

    //load from it self
    remote_load_int_1_0();
    error = check_self_int();

    if( error == 0) {
        bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, 0x4 );
        bsg_finish();
    } else {
        bsg_fail();
    }
}


////////////////////////////////////////////////////////////////////
int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);


  if (id == 0)          proc0();
  else if( id == 1 )    proc1();
  else                  bsg_wait_while(1);

  bsg_wait_while(1);
}

