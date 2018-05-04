//====================================================================
// bsg_dram_loopback.c
// 05/01/2018, shawnless.xie@gmail.com
//====================================================================
// This program will write and then read scattered data from dram
//

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VECTOR_LEN        4
#define DATA_VECT         { 0x03020100,0x07060504,0x0b0a0908, 0x0f0e0d0c}

//define the dram configurations
#define ROW_BITS          14
#define COL_BITS          10
#define BA_BITS           2

#define CELL_BYTES        2
#define COL_BYTES         (1 << COL_BITS) * ( CELL_BYTES )
#define ROW_BYTES         (1 << ROW_BITS) * COL_BYTES

//define different address patterns
#define ADDR_VECT_COLS    {128+0*4, 128+1*4, 128+2*4, 128+3*4}
#define COLS_PATTEN_ID    0x11111111

#define ADDR_VECT_ROWS    {0*COL_BYTES, 1*COL_BYTES, 2*COL_BYTES, 3*COL_BYTES}
#define ROWS_PATTEN_ID    0x22222222

#define ADDR_VECT_BANK    {0*ROW_BYTES, 1*ROW_BYTES, 2*ROW_BYTES, 3*ROW_BYTES}
#define BANK_PATTEN_ID    0x33333333

#define ADDR_VECT_CROSS_ROWS    {COL_BYTES-2*4, COL_BYTES-1*4, COL_BYTES, COL_BYTES+ 1*4}
#define CROSS_ROWS_PATTEN_ID    0x44444444

#define ADDR_VECT_CROSS_BANK    {ROW_BYTES-2*4, ROW_BYTES-1*4, ROW_BYTES, ROW_BYTES+ 1*4}
#define CROSS_BANK_PATTEN_ID    0x55555555

#define DRAM_X_CORD       1
#define DRAM_Y_CORD       1

int  data_vect[VECTOR_LEN] = DATA_VECT;

int  addr_vect_cols[VECTOR_LEN] = ADDR_VECT_COLS;
int  addr_vect_rows[VECTOR_LEN] = ADDR_VECT_ROWS;
int  addr_vect_bank[VECTOR_LEN] = ADDR_VECT_BANK;

int  addr_vect_cross_rows[VECTOR_LEN] = ADDR_VECT_CROSS_ROWS;
int  addr_vect_cross_bank[VECTOR_LEN] = ADDR_VECT_CROSS_BANK;

void scatter( int * addr_vect, int* data_vect, int patten_id){
        bsg_remote_ptr_io_store(0, 0x0, patten_id);
        //write dram
        for( int i=0; i< VECTOR_LEN; i++){
                 bsg_remote_store(DRAM_X_CORD,  DRAM_Y_CORD,   addr_vect[ i ],  data_vect[i]  );
        }

        int read_value;
        for( int j= VECTOR_LEN-1 ; j>=0 ; j--){
                bsg_remote_load(DRAM_X_CORD,  DRAM_Y_CORD,    addr_vect[ j ], read_value );

                bsg_remote_ptr_io_store(0, addr_vect[j], read_value);

                if( read_value != data_vect[ j ]  ){
                        bsg_remote_ptr_io_store(0, 0x0, read_value);
                        bsg_remote_ptr_io_store(0, 0x0, data_vect[j] );
                        bsg_fail();
                }
        }
}

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  if (id == 0) {
       scatter( addr_vect_cols, data_vect, COLS_PATTEN_ID);
       scatter( addr_vect_rows, data_vect, ROWS_PATTEN_ID);
       scatter( addr_vect_bank, data_vect, BANK_PATTEN_ID);

       scatter( addr_vect_cross_rows, data_vect, CROSS_ROWS_PATTEN_ID);
       scatter( addr_vect_cross_bank, data_vect, CROSS_BANK_PATTEN_ID);
       bsg_finish();
  }

  bsg_wait_while(1);
}
