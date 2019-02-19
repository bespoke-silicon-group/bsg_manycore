#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//turn on the debug 
//---------------------------------------------------------

#define BARRIER_X_START 1
#define BARRIER_Y_START 1

#define BARRIER_X_END (bsg_tiles_X - 1)
#define BARRIER_Y_END (bsg_tiles_Y - 1)
#define BARRIER_X_NUM  (BARRIER_X_END - BARRIER_X_START +1) 
#define BARRIER_Y_NUM  (BARRIER_Y_END - BARRIER_Y_START +1) 
#define BARRIER_TILES ( BARRIER_X_NUM * BARRIER_Y_NUM )

#define  BSG_BARRIER_DEBUG 1
#define  BSG_TILE_GROUP_X_DIM BARRIER_X_NUM
#define  BSG_TILE_GROUP_Y_DIM BARRIER_Y_NUM
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER (row_barrier_inst, col_barrier_inst, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);

////////////////////////////////////////////////////////////////////
int main() {
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);


  if(  (bsg_x>= BARRIER_X_START  && bsg_x <= BARRIER_X_END)  \
     &&(bsg_y>= BARRIER_Y_START  && bsg_y <= BARRIER_Y_END)   ){
        //----------------------------------------------------------------
        //1. differnt tiles will delay for different cycles.
        //----------------------------------------------------------------
        for( int i =0; i <= id; i++){
          for(int j=0; j<32; j++){
              asm volatile ("nop;");
          }
          bsg_remote_ptr_io_store(IO_X_INDEX, 0x100,  (id<<16) | i);
        }
        //----------------------------------------------------------------
        //2. sync the group
        //----------------------------------------------------------------
        bsg_tile_group_barrier(&row_barrier_inst, &col_barrier_inst);

        //----------------------------------------------------------------
        //3. All tiles print a heart beat packet.
        //----------------------------------------------------------------
                //addr 0x104: beat signal indicates sync'ed
                //            should be printed in a row.
        bsg_remote_ptr_io_store(IO_X_INDEX, 0x104,  id);

        //----------------------------------------------------------------
        //4. sync again.
        //----------------------------------------------------------------
        bsg_tile_group_barrier(&row_barrier_inst, &col_barrier_inst);

        //----------------------------------------------------------------
        //5. who ever runs fastest will terminate the simulation.
        //----------------------------------------------------------------
        bsg_finish();
  }
  bsg_wait_while(1);
}

