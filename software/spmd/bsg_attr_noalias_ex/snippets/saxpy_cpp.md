```
void saxpy_cpp(float  *  A, float  *  B, float *C, float alpha) {
   0:	00000793          	li	x15,0

00000004 <.L2>:
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
   4:	00f506b3          	add	x13,x10,x15
   8:	00f58733          	add	x14,x11,x15
   c:	0006a787          	flw	f15,0(x13)
  10:	00072707          	flw	f14,0(x14)
  14:	00478293          	addi	x5,x15,4
  18:	00f608b3          	add	x17,x12,x15
  1c:	70a7f043          	fmadd.s	f0,f15,f10,f14
  20:	00550833          	add	x16,x10,x5
  24:	00558333          	add	x6,x11,x5
  28:	0008a027          	fsw	f0,0(x17)
  2c:	00082087          	flw	f1,0(x16)
  30:	00032107          	flw	f2,0(x6)
  34:	00878393          	addi	x7,x15,8
  38:	00560e33          	add	x28,x12,x5
  3c:	10a0f1c3          	fmadd.s	f3,f1,f10,f2
  40:	00750eb3          	add	x29,x10,x7
  44:	00758f33          	add	x30,x11,x7
  48:	003e2027          	fsw	f3,0(x28)
  4c:	000ea207          	flw	f4,0(x29)
  50:	000f2287          	flw	f5,0(x30)
  54:	00c78f93          	addi	x31,x15,12
  58:	007606b3          	add	x13,x12,x7
  5c:	28a27343          	fmadd.s	f6,f4,f10,f5
  60:	01f50733          	add	x14,x10,x31
  64:	01f582b3          	add	x5,x11,x31
  68:	0066a027          	fsw	f6,0(x13)
  6c:	00072387          	flw	f7,0(x14)
  70:	0002a587          	flw	f11,0(x5)
  74:	01f608b3          	add	x17,x12,x31
  78:	01078793          	addi	x15,x15,16
  7c:	58a3f643          	fmadd.s	f12,f7,f10,f11
        for(int i = 0;  i < N_ELS; ++i) {
  80:	80078813          	addi	x16,x15,-2048
                C[i] = alpha * A[i] + B[i];
  84:	00c8a027          	fsw	f12,0(x17)
        for(int i = 0;  i < N_ELS; ++i) {
  88:	f6081ee3          	bnez	x16,4 <.L2>

0000008c <.LBE6>:
        }
}
  8c:	00008067          	ret

Command Line Flags: 

String dump of section '.GCC.command.line':
  [     0]  -I ../../../../bsg_manycore/software/spmd/common/
  [    75]  -I ../../../../bsg_manycore/software/bsg_manycore_lib
  [    ee]  -D bsg_tiles_X=1
  [    ff]  -D bsg_tiles_Y=1
  [   110]  -D bsg_global_X=4
  [   122]  -D bsg_global_Y=5
  [   134]  -D bsg_group_size=1
  [   148]  -D PREALLOCATE=0
  [   159]  -D HOST_DEBUG=0
  [   169]  saxpy-c.c
  [   173]  -march=rv32imaf
  [   183]  -mtune=bsg_vanilla_2020
  [   19b]  -mabi=ilp32f
  [   1a8]  -auxbase-strip saxpy-c.o
  [   1c1]  -g
  [   1c4]  -O2
  [   1c8]  -std=gnu99
  [   1d3]  -frecord-gcc-switches
  [   1e9]  -ffast-math
  [   1f5]  -fno-common
  [   201]  -ffunction-sections
  [   215]  -fweb
  [   21b]  -frename-registers
  [   22e]  -frerun-cse-after-loop
  [   245]  saxpy-c-2.c
  [   251]  -auxbase-strip saxpy-c-2.o
  [   26c]  saxpy-cpp.cpp
  [   27a]  -auxbase-strip saxpy-cpp.o
  [   295]  -std=c++11
  [   2a0]  saxpy-cpp-2.cpp
  [   2b0]  -auxbase-strip saxpy-cpp-2.o
  [   2cd]  main.cpp
  [   2d6]  -auxbase-strip main.o
  [   2ec]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_tile_config_vars.c
  [   379]  -auxbase-strip bsg_tile_config_vars.o
  [   39f]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_set_tile_x_y.c
  [   428]  -auxbase-strip bsg_set_tile_x_y.o
  [   44a]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_printf.c
  [   4cd]  -auxbase-strip bsg_printf.o

```
