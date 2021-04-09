// Test to perform several floating point operations, followed by integer operations to verify that
// bsg_manycore floating point unit is not operating during integer operations


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math_common.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

float float_data[K] __attribute__ ((section (".dram"))) = {
68.88436890, 51.59088135, -15.88568401, -48.21664810, 
2.25494432, -19.01317215, 56.75971603, -39.33745575, 
-4.68060923, 16.67640877, 81.62257385, 0.93737113, 
-43.63243103, 51.16083908, 23.67379951, -49.89873123, 
81.94924927, 96.55709839, 62.04344559, 80.43318939, 
-37.97048569, 45.96635056, 79.76765442, 36.79678726, 
-5.57145691, -79.85975647, -13.16563320, 22.17739487, 
82.60221100, 93.32127380, -4.59804487, 73.06198883, 
-47.90153885, 61.00556564, 9.73986053, -97.19165802, 
43.94093704, -20.23529243, 64.96899414, 33.63064194, 
-99.77143860, -1.28442669, 73.52055359, -51.21782303, 
-34.95912933, 74.09424591, -61.78658295, 13.50214767, 
-52.27681351, 93.50804901, 60.63589478, -10.40608597, 
-83.91083527, -35.98907852, 1.58812845, 86.56676483, 
-78.18843079, 10.25344944, 41.31228256, 9.48818207, 
62.89337158, 8.05672169, 92.76770782, 20.63712502
};

int int_data[N]   = {1, -2, 3, -4, 5, -6, 7, -8, 9,-10};

int print_value( unsigned int *p){
    int i;
    for(i=0; i<N; i++) 
        bsg_remote_ptr_io_store(IO_X_INDEX,0x0,p[i]);
}


///////////////////////////////////////////////////////
int main()
{
  bsg_set_tile_x_y();

  if(bsg_x == 0 && bsg_y == 0){
    float_math_test(float_data);
    int_math_test(int_data);
    bsg_finish();
  }

  bsg_wait_while(1);
}

