```
void saxpy_cpp_moreunroll(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha) {
   0:	00000793          	li	x15,0

00000004 <.L2>:
        float s = 0;
        bsg_unroll(8)
        for(int i = 0;  i < N_ELS; ++i) {
                C[i] = alpha * A[i] + B[i];
   4:	00478e93          	addi	x29,x15,4
   8:	00f506b3          	add	x13,x10,x15
   c:	00f58733          	add	x14,x11,x15
  10:	0006a707          	flw	f14,0(x13)
  14:	00072587          	flw	f11,0(x14)
  18:	00878e13          	addi	x28,x15,8
  1c:	01d502b3          	add	x5,x10,x29
  20:	01d583b3          	add	x7,x11,x29
  24:	0002a787          	flw	f15,0(x5)
  28:	0003a607          	flw	f12,0(x7)
  2c:	00c78313          	addi	x6,x15,12
  30:	01c50833          	add	x16,x10,x28
  34:	01c58f33          	add	x30,x11,x28
  38:	01078893          	addi	x17,x15,16
  3c:	00082007          	flw	f0,0(x16)
  40:	00650fb3          	add	x31,x10,x6
  44:	006586b3          	add	x13,x11,x6
  48:	000f2687          	flw	f13,0(x30)
  4c:	01478393          	addi	x7,x15,20
  50:	58a77243          	fmadd.s	f4,f14,f10,f11
  54:	0006a107          	flw	f2,0(x13)
  58:	011502b3          	add	x5,x10,x17
  5c:	01158733          	add	x14,x11,x17
  60:	000fa287          	flw	f5,0(x31)
  64:	01878693          	addi	x13,x15,24
  68:	60a7f343          	fmadd.s	f6,f15,f10,f12
  6c:	0002a387          	flw	f7,0(x5)
  70:	00072087          	flw	f1,0(x14)
  74:	00750833          	add	x16,x10,x7
  78:	00758f33          	add	x30,x11,x7
  7c:	01c78713          	addi	x14,x15,28
  80:	00f602b3          	add	x5,x12,x15
  84:	00d50fb3          	add	x31,x10,x13
  88:	68a07843          	fmadd.s	f16,f0,f10,f13
  8c:	00082887          	flw	f17,0(x16)
  90:	000f2187          	flw	f3,0(x30)
  94:	00d58833          	add	x16,x11,x13
  98:	0042a027          	fsw	f4,0(x5)
  9c:	000fae87          	flw	f29,0(x31)
  a0:	00e502b3          	add	x5,x10,x14
  a4:	00e58f33          	add	x30,x11,x14
  a8:	10a2fe43          	fmadd.s	f28,f5,f10,f2
  ac:	00082f07          	flw	f30,0(x16)
  b0:	01d60eb3          	add	x29,x12,x29
  b4:	006ea027          	fsw	f6,0(x29)
  b8:	08a3ffc3          	fmadd.s	f31,f7,f10,f1
  bc:	0002a587          	flw	f11,0(x5)
  c0:	000f2787          	flw	f15,0(x30)
  c4:	01c60e33          	add	x28,x12,x28
  c8:	010e2027          	fsw	f16,0(x28)
  cc:	18a8f643          	fmadd.s	f12,f17,f10,f3
  d0:	00660333          	add	x6,x12,x6
  d4:	01c32027          	fsw	f28,0(x6)
  d8:	f0aef743          	fmadd.s	f14,f29,f10,f30
  dc:	011608b3          	add	x17,x12,x17
  e0:	01f8a027          	fsw	f31,0(x17)
  e4:	78a5f043          	fmadd.s	f0,f11,f10,f15
  e8:	007603b3          	add	x7,x12,x7
  ec:	00c3a027          	fsw	f12,0(x7)
  f0:	00d606b3          	add	x13,x12,x13
  f4:	00e6a027          	fsw	f14,0(x13)
  f8:	00e60733          	add	x14,x12,x14
  fc:	02078793          	addi	x15,x15,32
 100:	00072027          	fsw	f0,0(x14)
        for(int i = 0;  i < N_ELS; ++i) {
 104:	80078f93          	addi	x31,x15,-2048
 108:	ee0f9ee3          	bnez	x31,4 <.L2>

0000010c <.LBE3>:
        }
}
 10c:	00008067          	ret

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
