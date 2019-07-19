//This kernel tests the functionality of scalar printing functions
//Including bsg_print_int, bsg_print_unsigned, bsg_print_hexadecimal,
//bsg_print_float, and bsg_print_float_scientific

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define MAGIC_INT    1234
#define MAGIC_UINT   99220011
#define MAGIC_HEX    0xA0A0
#define MAGIC_FLOAT  1843.50
#define MAGIC_SCI    2.25
int main(){
  bsg_set_tile_x_y();
  bsg_print_int(MAGIC_INT);
  bsg_print_unsigned(MAGIC_UINT);
  bsg_print_hexadecimal(MAGIC_HEX);
  bsg_print_float(MAGIC_FLOAT); 
  bsg_print_float_scientific(MAGIC_SCI);
  bsg_finish_x(IO_X_INDEX);
  return 0;
}
