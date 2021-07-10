```
void saxpy_c_noalias_noalias(float * bsg_attr_noalias * bsg_attr_noalias A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
   0:	00052803          	lw	x16,0(x10)
   4:	00452503          	lw	x10,4(x10)

00000008 <.LVL9>:
   8:	00000793          	li	x15,0

0000000c <.L27>:
   c:	00478613          	addi	x12,x15,4
  10:	00f808b3          	add	x17,x16,x15
  14:	00f50733          	add	x14,x10,x15
  18:	00878693          	addi	x13,x15,8
  1c:	0008a607          	flw	f12,0(x17)
  20:	00072787          	flw	f15,0(x14)
  24:	00c80333          	add	x6,x16,x12
  28:	00c502b3          	add	x5,x10,x12
  2c:	00c78393          	addi	x7,x15,12
  30:	00032687          	flw	f13,0(x6)
  34:	00d80e33          	add	x28,x16,x13
  38:	00d50eb3          	add	x29,x10,x13
  3c:	0002a087          	flw	f1,0(x5)
  40:	000e2707          	flw	f14,0(x28)
  44:	000ea007          	flw	f0,0(x29)
  48:	00780f33          	add	x30,x16,x7
  4c:	00750fb3          	add	x31,x10,x7
  50:	78a67143          	fmadd.s	f2,f12,f10,f15
  54:	000f2187          	flw	f3,0(x30)
  58:	000fa587          	flw	f11,0(x31)
  5c:	08a6f243          	fmadd.s	f4,f13,f10,f1
  60:	00f588b3          	add	x17,x11,x15
  64:	00a772c3          	fmadd.s	f5,f14,f10,f0
  68:	0028a027          	fsw	f2,0(x17)
  6c:	58a1f343          	fmadd.s	f6,f3,f10,f11
  70:	00c58633          	add	x12,x11,x12
  74:	00462027          	fsw	f4,0(x12)
  78:	00d58733          	add	x14,x11,x13
  7c:	00572027          	fsw	f5,0(x14)
  80:	007586b3          	add	x13,x11,x7
  84:	01078793          	addi	x15,x15,16
  88:	0066a027          	fsw	f6,0(x13)
        for(int i = 0;  i < N_ELS; ++i) {
  8c:	80078313          	addi	x6,x15,-2048
  90:	f6031ee3          	bnez	x6,c <.L27>

00000094 <.LBE11>:
        }
}
  94:	00008067          	ret

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
