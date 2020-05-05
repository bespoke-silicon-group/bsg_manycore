/************************************************************************************/
/* bsg_loader_suite/loopback                                                        */
/* 05/31/2019, mrutt@cs.washington.edu                                              */
/*                                                                                  */
/* This program will set its x,y variables and the origin will send a finish packet */
/************************************************************************************/


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define CACHE_NUM_SET 256
#define CACHE_NUM_WAY 2

int main()
{
        bsg_set_tile_x_y();

        int id = bsg_x_y_to_id(bsg_x, bsg_y);

        if (id == 1)
        {
                bsg_printf("hello\n");
                bsg_print_int((int)0xffffffff);
                bsg_print_unsigned(0xffffffff);
                bsg_print_hexadecimal(0xffffffff);
                bsg_print_float(2.1);
                bsg_print_float_scientific(1.1e6);
                bsg_finish_x(IO_X_INDEX);
        }
        else
        {
                bsg_wait_while(1);
        }
}
