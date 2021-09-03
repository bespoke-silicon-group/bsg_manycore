#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main()
{

  bsg_set_tile_x_y();

  bsg_print_int(__bsg_pod_x);
  bsg_print_int(__bsg_pod_y);  

  bsg_finish();
  
  bsg_wait_while(1);
}
