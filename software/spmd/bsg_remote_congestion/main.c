#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BUF_LEN    2
// Should be passed by the compiler options
//#define MASTER_X   0
//#define MASTER_Y   0

#if bsg_tiles_X != 4
#error "bsg_tiles_X should be 4 "
#elif bsg_tiles_Y != 8
#error "bsg_tiles_Y should be 8 "
#endif

#define XY_ID(x_cord, y_cord, X, Y)    ( ( (x_cord) *(X) +(y_cord) ) << 24  )
#define GEN_XY_VECTOR2(x_cord, y_cord, X, Y)  { 0x0 | XY_ID( x_cord, y_cord, X, Y)     \
                                              , 0x1 | XY_ID( x_cord, y_cord, X, Y)     \
                                              }
#define GEN_X_VECTOR8( X ) \
         GEN_XY_VECTOR2(X, 0, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 1, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 2, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 3, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 4, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 5, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 6, bsg_tiles_X, bsg_tiles_Y),  \
         GEN_XY_VECTOR2(X, 7, bsg_tiles_X, bsg_tiles_Y)   \

int RemoteArray[ bsg_tiles_X ][ bsg_tiles_Y ][ BUF_LEN ] ={
    {
        GEN_X_VECTOR8( 0 )
    },
    {
        GEN_X_VECTOR8( 1 )
    },
    {
        GEN_X_VECTOR8( 2 )
    },
    {
        GEN_X_VECTOR8( 3 )
    }
};

int  LocalArray[ BUF_LEN ] ;

int volatile finish_array[ bsg_tiles_X ][ bsg_tiles_Y ]={0};

//code runs on processor 0
void proc0(void){

    int need_wait;
    int i, j;

    do{
        need_wait=0;

        for( i=0; i< bsg_tiles_X; i++) {
            for( j=0; j< bsg_tiles_Y; j++){
                if( finish_array[i][j]  < 0 ) {
                    bsg_fail();
                }
                else if( finish_array[i][i] == 0 ) {
                    need_wait = 1;
                }
            }
        }

    } while( need_wait != 0);

    for(i=0; i<bsg_tiles_X; i++){
        for(j=0; j<bsg_tiles_Y; j++){
            int *ptr = bsg_remote_ptr_io(IO_X_INDEX, ( (i*bsg_tiles_Y + j)*4) );
            asm( "sw %[val],0(%[addr])" :: [val] "r"(finish_array[i][j]), [addr] "r"(ptr) ) ;
        }
    }

    bsg_finish();

}

//code runs on any tiles
void procX(){
   int i;
   int error = 0;
   for ( i=0; i< BUF_LEN; i++ ){
      LocalArray[ i ] =  * bsg_remote_ptr( MASTER_X, MASTER_Y, &(RemoteArray[bsg_x][bsg_y][i]) );
   }

    for ( i=0; i< BUF_LEN; i++){
        int expect = i |  XY_ID( bsg_x, bsg_y, bsg_tiles_X, bsg_tiles_Y);
        if( LocalArray[ i ] != expect  ){
            bsg_remote_store(MASTER_X, MASTER_Y, &(finish_array[bsg_x][bsg_y]), -1);
            error = 1;
            break;
        }
    }

    if( error == 0) {
        bsg_remote_store(MASTER_X, MASTER_Y, &(finish_array[bsg_x][bsg_y]), 0x1 );
    }

}


////////////////////////////////////////////////////////////////////
int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);
  int master_id = bsg_x_y_to_id( MASTER_X, MASTER_Y);

  procX();

  if (id == master_id)          proc0();

  bsg_wait_while(1);
}

