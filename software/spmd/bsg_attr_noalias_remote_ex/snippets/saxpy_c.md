```
void saxpy_c(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
   0:	000017b7          	lui	x15,0x1
   4:	80078293          	addi	x5,x15,-2048 # 800 <.LASF2+0x68c>
   8:	00550333          	add	x6,x10,x5

0000000c <.L2>:
                C[i] = alpha * A[i] + B[i];
   c:	00052607          	flw	f12,0(x10)
  10:	0005a107          	flw	f2,0(x11)
  14:	00452687          	flw	f13,4(x10)
  18:	0045a087          	flw	f1,4(x11)
  1c:	00852707          	flw	f14,8(x10)
  20:	0085a007          	flw	f0,8(x11)
  24:	00c52787          	flw	f15,12(x10)
  28:	00c5a587          	flw	f11,12(x11)
  2c:	10a671c3          	fmadd.s	f3,f12,f10,f2
  30:	08a6f243          	fmadd.s	f4,f13,f10,f1
  34:	00a772c3          	fmadd.s	f5,f14,f10,f0
  38:	58a7f343          	fmadd.s	f6,f15,f10,f11
  3c:	00362027          	fsw	f3,0(x12)
  40:	00462227          	fsw	f4,4(x12)
  44:	00562427          	fsw	f5,8(x12)
  48:	00662627          	fsw	f6,12(x12)
        for(int i = 0;  i < N_ELS; ++i) {
  4c:	01050513          	addi	x10,x10,16
  50:	01058593          	addi	x11,x11,16
  54:	01060613          	addi	x12,x12,16
  58:	fa651ae3          	bne	x10,x6,c <.L2>

0000005c <.LBE2>:
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
  [   2a6]  saxpy-c-2.c
  [   2b2]  -auxbase-strip saxpy-c-2.o
  [   2cd]  main.cpp
  [   2d6]  -auxbase-strip main.o
  [   2ec]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_tile_config_vars.c
  [   379]  -auxbase-strip bsg_tile_config_vars.o
  [   39f]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_set_tile_x_y.c
  [   428]  -auxbase-strip bsg_set_tile_x_y.o
  [   44a]  ../../../../bsg_manycore/software/bsg_manycore_lib/bsg_printf.c
  [   4cd]  -auxbase-strip bsg_printf.o

```
