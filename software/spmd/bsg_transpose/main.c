#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_barrier.h"
// This test will transpose a matrix distributed accross the tile
//---------------------------------------------------------
// outputs:
//            row num _ col num
//              0x0000_0000
//              0x0000_0001
//              0x0000_0002
//              0x0000_0003
//              0x0001_0000

//how many data each tile holds?
#define SUB_ROW_NUM     2
#define SUB_COL_NUM     3
#define DATA_PER_TILE   (SUB_ROW_NUM * SUB_COL_NUM)

#define TILE_DIM        4
#define NUM_X_TILES     TILE_DIM
#define NUM_Y_TILES     TILE_DIM


#define MATRIX_ROWS     ( SUB_ROW_NUM * NUM_Y_TILES)
#define MATRIX_COLS     ( SUB_COL_NUM * NUM_X_TILES)

#define NUM_TILES       ( NUM_X_TILES * NUM_Y_TILES)

//-----------------------------------------------------------------------------
// Control signals
bsg_barrier tile0_barrier=BSG_BARRIER_INIT( 0, (NUM_X_TILES-1), 0, (NUM_Y_TILES-1));

bsg_barrier tile0_trans_barrier=BSG_BARRIER_INIT( 0, (NUM_Y_TILES-1), 0, (NUM_X_TILES-1));

//-----------------------------------------------------------------------------
// The matrix data
typedef int source_array    [ SUB_COL_NUM ];
typedef int dest_array      [ SUB_ROW_NUM ];

int local_source[ SUB_ROW_NUM ] [ SUB_COL_NUM ];
int local_dest  [ SUB_COL_NUM ] [ SUB_ROW_NUM ];

void init_source( source_array *p_source ){
    int sub_i_start = bsg_y * SUB_ROW_NUM;
    int sub_j_start = bsg_x * SUB_COL_NUM;
    for( int i= 0; i< SUB_ROW_NUM; i++){
        for( int j= 0; j< SUB_COL_NUM; j++){
            int msb = ( i + sub_i_start) << 16  ;
            int lsb = ( j + sub_j_start)        ;
            p_source[ i ] [ j ] =  msb | lsb    ;
        }
    }
}

void transpose( source_array *p_source, dest_array * p_dest ){
    //switch the bsg_x, bsg_y to get source ptr
    source_array * p_remote_source
            =  ( source_array *)bsg_remote_ptr( bsg_y, bsg_x,  &( p_source[0][0]) );

    for( int i=0; i< SUB_ROW_NUM; i++){
        for( int j=0; j< SUB_COL_NUM; j++){
            p_dest[ j ] [ i ] = p_remote_source[ i ] [ j ];
        }
    }
}

//print the result with colum major layout
void print_result( dest_array * p_dest ){
    for( int i=0; i< MATRIX_ROWS  ;  i++){
        for( int j=0; j< MATRIX_COLS; j++){  //j is the row number
            int y_cord = j / SUB_COL_NUM ;
            int x_cord = i / SUB_ROW_NUM ;
            int row_id = j % SUB_COL_NUM ;
            int col_id = i % SUB_ROW_NUM ;

            unsigned int data = * ( bsg_remote_ptr( x_cord, y_cord, &( p_dest[row_id][col_id] ) ) );
            bsg_remote_ptr_io_store( 0, 0, data);
        }
    }
}
void print_result1( dest_array * p_dest ){
    for( int i=0; i< SUB_COL_NUM  ;  i++){
        for( int j=0; j< SUB_ROW_NUM; j++){
            unsigned int data = * ( bsg_remote_ptr( 1, 0, &( p_dest[ i ][ j ] ) ) );
            bsg_remote_ptr_io_store( 0, 0, data);
        }
    }
}

////////////////////////////////////////////////////////////////////
int main() {
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);


 if( (bsg_x < NUM_X_TILES) && (bsg_y < NUM_Y_TILES) ){

    init_source( local_source );

   bsg_barrier_wait( &tile0_barrier, 0, 0);

   //start to transpose
   if( id == 0) bsg_remote_ptr_io_store(0x0, 0x0, 0x0000cab0);

   transpose( local_source, local_dest);

   //finish transpose
   bsg_barrier_wait( &tile0_trans_barrier, 0, 0);

   if( id == 0) {
       bsg_remote_ptr_io_store(0x0, 0x0, 0x0000cab1);
       print_result( local_dest );
       bsg_finish();
   }

 }

  bsg_wait_while(1);
}

