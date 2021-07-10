```
void saxpy_cpp_noalias(float * bsg_attr_noalias A, float * bsg_attr_noalias B, float * bsg_attr_noalias C, float alpha) {
   0:	00000793          	li	x15,0

00000004 <.L9>:
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
   4:	00478813          	addi	x16,x15,4
   8:	00f508b3          	add	x17,x10,x15
   c:	00f58733          	add	x14,x11,x15
  10:	00878693          	addi	x13,x15,8
  14:	0008a607          	flw	f12,0(x17)
  18:	00072787          	flw	f15,0(x14)
  1c:	01050333          	add	x6,x10,x16
  20:	010582b3          	add	x5,x11,x16
  24:	00c78393          	addi	x7,x15,12
  28:	00032687          	flw	f13,0(x6)
  2c:	00d50e33          	add	x28,x10,x13
  30:	00d58eb3          	add	x29,x11,x13
  34:	0002a087          	flw	f1,0(x5)
  38:	000e2707          	flw	f14,0(x28)
  3c:	000ea007          	flw	f0,0(x29)
  40:	00750f33          	add	x30,x10,x7
  44:	00758fb3          	add	x31,x11,x7
  48:	78a67143          	fmadd.s	f2,f12,f10,f15
  4c:	000f2187          	flw	f3,0(x30)
  50:	000fa587          	flw	f11,0(x31)
  54:	08a6f243          	fmadd.s	f4,f13,f10,f1
  58:	00f608b3          	add	x17,x12,x15
  5c:	00a772c3          	fmadd.s	f5,f14,f10,f0
  60:	0028a027          	fsw	f2,0(x17)
  64:	58a1f343          	fmadd.s	f6,f3,f10,f11
  68:	01060833          	add	x16,x12,x16
  6c:	00482027          	fsw	f4,0(x16)
  70:	00d60733          	add	x14,x12,x13
  74:	00572027          	fsw	f5,0(x14)
  78:	007606b3          	add	x13,x12,x7
  7c:	01078793          	addi	x15,x15,16
  80:	0066a027          	fsw	f6,0(x13)
        for(int i = 0;  i < N_ELS; ++i) {
  84:	80078313          	addi	x6,x15,-2048
  88:	f6031ee3          	bnez	x6,4 <.L9>

0000008c <.LBE8>:
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
