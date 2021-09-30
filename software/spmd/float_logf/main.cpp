// The intent of this test is to demonstrate a behavior that caused an RTL simulation error.
// The error occured when this test is run, and produced this message:
// bsg_manycore/v/vanilla_bean/fcsr.v", 187: spmd_testbench.tb.DUT.py[0].podrow.px[0].pod.mc_y[0].mc_x[0].mc.y[0].x[0].tile.proc.h.z.vcore.fcsr0.unnamed$$_3: started at 1897000ps failed at 1897000ps
//        Offending '(~(|fflags_v_i))'
// Error: "bsg_manycore/v/vanilla_bean/fcsr.v", 187: spmd_testbench.tb.DUT.py[0].podrow.px[0].pod.mc_y[0].mc_x[0].mc.y[0].x[0].tile.proc.h.z.vcore.fcsr0.unnamed$$_3: at time 1897000 ps
// Exception cannot be accrued while being written by fcsr op.
// 
// This issue was resolved by PR 587 in BSG Manycore
//
// Author: drichmond

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <cmath>

int main(){
        bsg_set_tile_x_y();

        if ((__bsg_x == 0) && (__bsg_y == 0)){
                float data[4] = {-1.0f, -0.0f, 0.0f, 1.0f, 2.718282f};

                for (int i = 0; i < 5; i++){
                        data[i] = logf(data[i]);
                        bsg_print_float(data[i]);
                }

                if(data[0] != NAN){
                        bsg_fail();
                }
                if(data[1] != -INFINITY){
                        bsg_fail();
                }
                if(data[2] != -INFINITY){
                        bsg_fail();
                }
                if(data[3] != 0.0f){
                        bsg_fail();
                }
                if(data[4] != 1.0f){
                        bsg_fail();
                }
                bsg_finish();
        }

        bsg_wait_while(1);
}
