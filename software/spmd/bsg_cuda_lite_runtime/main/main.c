#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_cuda_lite_runtime.h"


int main()
{
  bsg_set_tile_x_y();

/*
  bsg_remote_int_ptr origin_x_ptr;
  bsg_remote_int_ptr origin_y_ptr;

  origin_x_ptr = bsg_remote_ptr_control( __bsg_x, __bsg_y, CSR_TGO_X );
  origin_y_ptr = bsg_remote_ptr_control( __bsg_x, __bsg_y, CSR_TGO_Y );

  int origin_x = * origin_x_ptr;
  int origin_y = * origin_y_ptr;


  bsg_remote_ptr_io_store(IO_X_INDEX, 0x100, origin_x);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x200, origin_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x400, bsg_tiles_X);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x800, bsg_tiles_Y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x1000, __bsg_x);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, __bsg_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x3000, __bsg_grp_org_x);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x4000, __bsg_grp_org_y);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x5000, __bsg_id);
*/
  __wait_until_valid_func();
}

