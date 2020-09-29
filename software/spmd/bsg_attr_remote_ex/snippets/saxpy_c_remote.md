```
void saxpy_c_remote(float bsg_attr_remote * A, float bsg_attr_remote * B, float bsg_attr_remote * C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
   0:	000017b7          	lui	x15,0x1
   4:	80078293          	addi	x5,x15,-2048 # 800 <.LASF2+0x685>
   8:	00550333          	add	x6,x10,x5

0000000c <.L9>:
                 C[i] = alpha * A[i] + B[i];
   c:	00052787          	flw	f15,0(x10)
  10:	0005a707          	flw	f14,0(x11)
  14:	01060613          	addi	x12,x12,16
  18:	01050513          	addi	x10,x10,16
  1c:	70a7f043          	fmadd.s	f0,f15,f10,f14
  20:	01058593          	addi	x11,x11,16
  24:	fe062827          	fsw	f0,-16(x12)
  28:	ff452087          	flw	f1,-12(x10)
  2c:	ff45a107          	flw	f2,-12(x11)
  30:	10a0f1c3          	fmadd.s	f3,f1,f10,f2
  34:	fe362a27          	fsw	f3,-12(x12)
  38:	ff852207          	flw	f4,-8(x10)
  3c:	ff85a287          	flw	f5,-8(x11)
  40:	28a27343          	fmadd.s	f6,f4,f10,f5
  44:	fe662c27          	fsw	f6,-8(x12)
  48:	ffc52387          	flw	f7,-4(x10)
  4c:	ffc5a587          	flw	f11,-4(x11)
  50:	58a3f643          	fmadd.s	f12,f7,f10,f11
  54:	fec62e27          	fsw	f12,-4(x12)
        for(int i = 0;  i < N_ELS; ++i) {
  58:	fa651ae3          	bne	x10,x6,c <.L9>

0000005c <.LBE4>:
        }
}
  5c:	00008067          	ret

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
  [   245]  saxpy-cpp.cpp
  [   253]  -auxbase-strip saxpy-cpp.o
  [   26e]  -std=c++11
  [   279]  saxpy-cpp-2.cpp
  [   289]  -auxbase-strip saxpy-cpp-2.o
  [   2a6]  main.cpp
  [   2af]  -auxbase-strip main.o
  [   2c5]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_tile_config_vars.c
  [   352]  -auxbase-strip bsg_tile_config_vars.o
  [   378]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_set_tile_x_y.c
  [   401]  -auxbase-strip bsg_set_tile_x_y.o
  [   423]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_printf.c
  [   4a6]  -auxbase-strip bsg_printf.o

```
