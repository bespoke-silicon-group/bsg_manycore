//This kernel tests the functionality of scalar printing functions
//Including bsg_print_int, bsg_print_unsigned, bsg_print_hexadecimal,
//bsg_print_float, and bsg_print_float_scientific

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_scalar_print() {

	bsg_print_int(__bsg_id);
	bsg_print_unsigned(__bsg_id);
	bsg_print_hexadecimal(__bsg_id);
	bsg_print_float(((float)__bsg_id) / 1000); 
	bsg_print_float_scientific(((float)__bsg_id) / 1000);
	
	barrier.sync();	
	return 0;
}
