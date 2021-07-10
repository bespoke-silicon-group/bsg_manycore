```
void saxpy_cpp_cast(float * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        float (&xy)[2][N_ELS] = *reinterpret_cast<float (*)[2][N_ELS]> (A);
   0:	00001737          	lui	x14,0x1

00000004 <.LBB17>:
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
   4:	80070793          	addi	x15,x14,-2048 # 800 <.LASF9+0x601>
   8:	00f50333          	add	x6,x10,x15
   c:	00e502b3          	add	x5,x10,x14

00000010 <.L45>:
                C[i] = alpha * xy[0][i] + xy[1][i];
  10:	80032607          	flw	f12,-2048(x6)
  14:	00032107          	flw	f2,0(x6)
  18:	80432687          	flw	f13,-2044(x6)
  1c:	00432087          	flw	f1,4(x6)
  20:	80832707          	flw	f14,-2040(x6)
  24:	00832007          	flw	f0,8(x6)
  28:	80c32787          	flw	f15,-2036(x6)
  2c:	00c32587          	flw	f11,12(x6)
  30:	10a671c3          	fmadd.s	f3,f12,f10,f2
  34:	08a6f243          	fmadd.s	f4,f13,f10,f1
  38:	00a772c3          	fmadd.s	f5,f14,f10,f0
  3c:	58a7f343          	fmadd.s	f6,f15,f10,f11
  40:	0035a027          	fsw	f3,0(x11)
  44:	0045a227          	fsw	f4,4(x11)
  48:	0055a427          	fsw	f5,8(x11)
  4c:	0065a627          	fsw	f6,12(x11)
        for(int i = 0;  i < N_ELS; ++i) {
  50:	01030313          	addi	x6,x6,16
  54:	01058593          	addi	x11,x11,16
  58:	fa531ce3          	bne	x6,x5,10 <.L45>

0000005c <.LBE17>:
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
