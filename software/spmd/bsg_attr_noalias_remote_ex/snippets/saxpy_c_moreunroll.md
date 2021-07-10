```
void saxpy_c_moreunroll(float bsg_attr_remote * bsg_attr_noalias A, float bsg_attr_remote * bsg_attr_noalias B, float bsg_attr_remote * bsg_attr_noalias C, float alpha) {
        float s = 0;
        bsg_unroll(8)
        for(int i = 0;  i < N_ELS; ++i) {
   0:	000017b7          	lui	x15,0x1
   4:	80078293          	addi	x5,x15,-2048 # 800 <.LASF2+0x67f>
   8:	00550333          	add	x6,x10,x5

0000000c <.L2>:
                C[i] = alpha * A[i] + B[i];
   c:	00052107          	flw	f2,0(x10)
  10:	0005ae07          	flw	f28,0(x11)
  14:	00452087          	flw	f1,4(x10)
  18:	0045a887          	flw	f17,4(x11)
  1c:	00852007          	flw	f0,8(x10)
  20:	0085a807          	flw	f16,8(x11)
  24:	00c52587          	flw	f11,12(x10)
  28:	00c5a387          	flw	f7,12(x11)
  2c:	01052607          	flw	f12,16(x10)
  30:	0105a307          	flw	f6,16(x11)
  34:	01452687          	flw	f13,20(x10)
  38:	0145a287          	flw	f5,20(x11)
  3c:	01852707          	flw	f14,24(x10)
  40:	0185a207          	flw	f4,24(x11)
  44:	01c52787          	flw	f15,28(x10)
  48:	01c5a187          	flw	f3,28(x11)
  4c:	e0a17ec3          	fmadd.s	f29,f2,f10,f28
  50:	88a0ff43          	fmadd.s	f30,f1,f10,f17
  54:	80a07fc3          	fmadd.s	f31,f0,f10,f16
  58:	38a5f143          	fmadd.s	f2,f11,f10,f7
  5c:	30a67e43          	fmadd.s	f28,f12,f10,f6
  60:	28a6f0c3          	fmadd.s	f1,f13,f10,f5
  64:	20a778c3          	fmadd.s	f17,f14,f10,f4
  68:	18a7f043          	fmadd.s	f0,f15,f10,f3
  6c:	01d62027          	fsw	f29,0(x12)
  70:	01e62227          	fsw	f30,4(x12)
  74:	01f62427          	fsw	f31,8(x12)
  78:	00262627          	fsw	f2,12(x12)
  7c:	01c62827          	fsw	f28,16(x12)
  80:	00162a27          	fsw	f1,20(x12)
  84:	01162c27          	fsw	f17,24(x12)
  88:	00062e27          	fsw	f0,28(x12)
        for(int i = 0;  i < N_ELS; ++i) {
  8c:	02050513          	addi	x10,x10,32
  90:	02058593          	addi	x11,x11,32
  94:	02060613          	addi	x12,x12,32
  98:	f6651ae3          	bne	x10,x6,c <.L2>

0000009c <.LBE2>:
        }
}
  9c:	00008067          	ret

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
