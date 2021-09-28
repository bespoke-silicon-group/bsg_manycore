#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

int main(){
        bsg_set_tile_x_y();

        if ((__bsg_x == 0) && (__bsg_y == 0)){
                float data[4] = {-1.0f, -0.0f, 0.0f, 1.0f};

                for (int i = 0; i < 4; i++){
                        bsg_print_float(logf(data[i]));
                }
    
                bsg_finish();
        }

        bsg_wait_while(1);
}
