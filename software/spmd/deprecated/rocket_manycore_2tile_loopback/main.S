//====================================================================
// main.S
// 05/06/2017, shawnless.xie@gmail.com
//====================================================================
// This is the basic loopback assemble test for rocket+manycore


.text
.global sm_start; sm_start:
la      a0,  mc_output_ptr  ;
la      a1,  mc_output_data ;

// the remote address is stored in a2
lw      a2,  0x0(a0)        ;   
// the data is stored in t0
lw      t0,  0x0(a1)        ;
sw      t0,  0x0(a2)        ; 
//spining here.
lr.w    t0,  0x0(a0)        ;

//====================================================================
//Data section starts
.data
.global mc_output_ptr;  mc_output_ptr:
.int   0x0
.global mc_output_data; mc_output_data:

