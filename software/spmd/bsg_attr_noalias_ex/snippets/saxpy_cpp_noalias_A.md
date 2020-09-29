```
void saxpy_cpp_noalias_A(float * bsg_attr_noalias * A, float * bsg_attr_noalias C, float alpha) {
        bsg_unroll(4)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
   0:	00052803          	lw	x16,0(x10)
   4:	00452603          	lw	x12,4(x10)
   8:	00000793          	li	x15,0

0000000c <.L15>:
   c:	00f806b3          	add	x13,x16,x15
  10:	00f60733          	add	x14,x12,x15
  14:	0006a787          	flw	f15,0(x13)
  18:	00072707          	flw	f14,0(x14)
  1c:	00478293          	addi	x5,x15,4
  20:	00f588b3          	add	x17,x11,x15
  24:	70a7f043          	fmadd.s	f0,f15,f10,f14
  28:	00580533          	add	x10,x16,x5
  2c:	00560333          	add	x6,x12,x5
  30:	0008a027          	fsw	f0,0(x17)
  34:	00052087          	flw	f1,0(x10)
  38:	00032107          	flw	f2,0(x6)
  3c:	00878393          	addi	x7,x15,8
  40:	00558e33          	add	x28,x11,x5
  44:	10a0f1c3          	fmadd.s	f3,f1,f10,f2
  48:	00780eb3          	add	x29,x16,x7
  4c:	00760f33          	add	x30,x12,x7
  50:	003e2027          	fsw	f3,0(x28)
  54:	000ea207          	flw	f4,0(x29)
  58:	000f2287          	flw	f5,0(x30)
  5c:	00c78f93          	addi	x31,x15,12
  60:	007586b3          	add	x13,x11,x7
  64:	28a27343          	fmadd.s	f6,f4,f10,f5
  68:	01f80733          	add	x14,x16,x31
  6c:	01f602b3          	add	x5,x12,x31
  70:	0066a027          	fsw	f6,0(x13)
  74:	00072387          	flw	f7,0(x14)
  78:	0002a587          	flw	f11,0(x5)
  7c:	01f588b3          	add	x17,x11,x31
  80:	01078793          	addi	x15,x15,16
  84:	58a3f643          	fmadd.s	f12,f7,f10,f11
        for(int i = 0;  i < N_ELS; ++i) {
  88:	80078513          	addi	x10,x15,-2048
                C[i] = alpha * A[0][i] + A[1][i];
  8c:	00c8a027          	fsw	f12,0(x17)
        for(int i = 0;  i < N_ELS; ++i) {
  90:	f6051ee3          	bnez	x10,c <.L15>

00000094 <.LBE9>:
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
