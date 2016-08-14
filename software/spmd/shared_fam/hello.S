
hello.riscv:     file format elf32-littleriscv


Disassembly of section .text:

00000100 <user_trap_entry>:
 100:	00000793          	li	a5,0
 104:	78079073          	csrw	mucycle_deltah,a5
 108:	0000006f          	j	108 <user_trap_entry+0x8>
 10c:	00000013          	nop
 110:	00000013          	nop
 114:	00000013          	nop
 118:	00000013          	nop
 11c:	00000013          	nop
 120:	00000013          	nop
 124:	00000013          	nop
 128:	00000013          	nop
 12c:	00000013          	nop
 130:	00000013          	nop
 134:	00000013          	nop
 138:	00000013          	nop
 13c:	00000013          	nop

00000140 <supervisor_trap_entry>:
 140:	00100793          	li	a5,1
 144:	78079073          	csrw	mucycle_deltah,a5
 148:	0000006f          	j	148 <supervisor_trap_entry+0x8>
 14c:	00000013          	nop
 150:	00000013          	nop
 154:	00000013          	nop
 158:	00000013          	nop
 15c:	00000013          	nop
 160:	00000013          	nop
 164:	00000013          	nop
 168:	00000013          	nop
 16c:	00000013          	nop
 170:	00000013          	nop
 174:	00000013          	nop
 178:	00000013          	nop
 17c:	00000013          	nop

00000180 <hypervisor_trap_entry>:
 180:	00200793          	li	a5,2
 184:	78079073          	csrw	mucycle_deltah,a5
 188:	0000006f          	j	188 <hypervisor_trap_entry+0x8>
 18c:	00000013          	nop
 190:	00000013          	nop
 194:	00000013          	nop
 198:	00000013          	nop
 19c:	00000013          	nop
 1a0:	00000013          	nop
 1a4:	00000013          	nop
 1a8:	00000013          	nop
 1ac:	00000013          	nop
 1b0:	00000013          	nop
 1b4:	00000013          	nop
 1b8:	00000013          	nop
 1bc:	00000013          	nop

000001c0 <machine_trap_entry>:
 1c0:	00300793          	li	a5,3
 1c4:	78079073          	csrw	mucycle_deltah,a5
 1c8:	0000006f          	j	1c8 <machine_trap_entry+0x8>
 1cc:	00000013          	nop
 1d0:	00000013          	nop
 1d4:	00000013          	nop
 1d8:	00000013          	nop
 1dc:	00000013          	nop
 1e0:	00000013          	nop
 1e4:	00000013          	nop
 1e8:	00000013          	nop
 1ec:	00000013          	nop
 1f0:	00000013          	nop
 1f4:	00000013          	nop
 1f8:	00000013          	nop
 1fc:	00000013          	nop

00000200 <_start>:
 200:	00000093          	li	ra,0
 204:	00000113          	li	sp,0
 208:	00000193          	li	gp,0
 20c:	00000213          	li	tp,0
 210:	00000293          	li	t0,0
 214:	00000313          	li	t1,0
 218:	00000393          	li	t2,0
 21c:	00000413          	li	s0,0
 220:	00000493          	li	s1,0
 224:	00000513          	li	a0,0
 228:	00000593          	li	a1,0
 22c:	00000613          	li	a2,0
 230:	00000693          	li	a3,0
 234:	00000713          	li	a4,0
 238:	00000793          	li	a5,0
 23c:	00000813          	li	a6,0
 240:	00000893          	li	a7,0
 244:	00000913          	li	s2,0
 248:	00000993          	li	s3,0
 24c:	00000a13          	li	s4,0
 250:	00000a93          	li	s5,0
 254:	00000b13          	li	s6,0
 258:	00000b93          	li	s7,0
 25c:	00000c13          	li	s8,0
 260:	00000c93          	li	s9,0
 264:	00000d13          	li	s10,0
 268:	00000d93          	li	s11,0
 26c:	00000e13          	li	t3,0
 270:	00000e93          	li	t4,0
 274:	00000f13          	li	t5,0
 278:	00000f93          	li	t6,0
 27c:	03000293          	li	t0,48
 280:	3002b073          	csrc	mstatus,t0
 284:	00800293          	li	t0,8
 288:	3002a073          	csrs	mstatus,t0
 28c:	000032b7          	lui	t0,0x3
 290:	3002a073          	csrs	mstatus,t0
 294:	0000c2b7          	lui	t0,0xc
 298:	3002a073          	csrs	mstatus,t0
 29c:	300022f3          	csrr	t0,mstatus
 2a0:	0000c337          	lui	t1,0xc
 2a4:	0062f333          	and	t1,t0,t1
 2a8:	00003337          	lui	t1,0x3
 2ac:	0062f333          	and	t1,t0,t1
 2b0:	00030263          	beqz	t1,2b4 <_start+0xb4>
 2b4:	00004197          	auipc	gp,0x4
 2b8:	60c18193          	addi	gp,gp,1548 # 48c0 <_gp>
 2bc:	00004217          	auipc	tp,0x4
 2c0:	e8b20213          	addi	tp,tp,-373 # 4147 <_end+0x3f>
 2c4:	fc027213          	andi	tp,tp,-64
 2c8:	00008137          	lui	sp,0x8
 2cc:	ffc10113          	addi	sp,sp,-4 # 7ffc <_gp+0x373c>
 2d0:	0900006f          	j	360 <main>
 2d4:	10000073          	0x10000073

000002d8 <bsg_set_tile_x_y>:
 2d8:	800007b7          	lui	a5,0x80000
 2dc:	80418593          	addi	a1,gp,-2044 # 40c4 <bsg_x>
 2e0:	00f5e833          	or	a6,a1,a5
 2e4:	80018513          	addi	a0,gp,-2048 # 40c0 <bsg_y>
 2e8:	00082023          	sw	zero,0(a6)
 2ec:	00f56633          	or	a2,a0,a5
 2f0:	00062023          	sw	zero,0(a2)
 2f4:	8041a283          	lw	t0,-2044(gp) # 40c4 <bsg_x>
 2f8:	fe02cee3          	bltz	t0,2f4 <bsg_set_tile_x_y+0x1c>
 2fc:	8001a303          	lw	t1,-2048(gp) # 40c0 <bsg_y>
 300:	fe034ee3          	bltz	t1,2fc <bsg_set_tile_x_y+0x24>
 304:	8041a383          	lw	t2,-2044(gp) # 40c4 <bsg_x>
 308:	04039a63          	bnez	t2,35c <bsg_set_tile_x_y+0x84>
 30c:	8001ae03          	lw	t3,-2048(gp) # 40c0 <bsg_y>
 310:	040e1663          	bnez	t3,35c <bsg_set_tile_x_y+0x84>
 314:	00082023          	sw	zero,0(a6)
 318:	a0000eb7          	lui	t4,0xa0000
 31c:	00062023          	sw	zero,0(a2)
 320:	01d5ef33          	or	t5,a1,t4
 324:	000f2023          	sw	zero,0(t5)
 328:	00100f93          	li	t6,1
 32c:	90000737          	lui	a4,0x90000
 330:	01d567b3          	or	a5,a0,t4
 334:	01f7a023          	sw	t6,0(a5) # 80000000 <_gp+0x7fffb740>
 338:	00e5e6b3          	or	a3,a1,a4
 33c:	01f6a023          	sw	t6,0(a3)
 340:	b0000837          	lui	a6,0xb0000
 344:	00e56633          	or	a2,a0,a4
 348:	00062023          	sw	zero,0(a2)
 34c:	0105e5b3          	or	a1,a1,a6
 350:	01f5a023          	sw	t6,0(a1)
 354:	01056533          	or	a0,a0,a6
 358:	01f52023          	sw	t6,0(a0)
 35c:	00008067          	ret

Disassembly of section .text.startup:

00000360 <main>:
 360:	ff010113          	addi	sp,sp,-16
 364:	00112623          	sw	ra,12(sp)
 368:	f71ff0ef          	jal	2d8 <bsg_set_tile_x_y>
 36c:	8001a783          	lw	a5,-2048(gp) # 40c0 <bsg_y>
 370:	8041a703          	lw	a4,-2044(gp) # 40c4 <bsg_x>
 374:	00179293          	slli	t0,a5,0x1
 378:	00e28333          	add	t1,t0,a4
 37c:	0a031263          	bnez	t1,420 <main+0xc0>
 380:	000040b7          	lui	ra,0x4
 384:	00008393          	mv	t2,ra
 388:	0003a607          	flw	fa2,0(t2)
 38c:	0403a087          	flw	ft1,64(t2)
 390:	0043a687          	flw	fa3,4(t2)
 394:	0443a007          	flw	ft0,68(t2)
 398:	0083a707          	flw	fa4,8(t2)
 39c:	0483a507          	flw	fa0,72(t2)
 3a0:	00c3a787          	flw	fa5,12(t2)
 3a4:	04c3a587          	flw	fa1,76(t2)
 3a8:	00167153          	fadd.s	ft2,fa2,ft1
 3ac:	0006f1d3          	fadd.s	ft3,fa3,ft0
 3b0:	00a77253          	fadd.s	ft4,fa4,fa0
 3b4:	00b7f2d3          	fadd.s	ft5,fa5,fa1
 3b8:	0803a307          	flw	ft6,128(t2)
 3bc:	80818e13          	addi	t3,gp,-2040 # 40c8 <output>
 3c0:	a02326d3          	feq.s	a3,ft6,ft2
 3c4:	002e2027          	fsw	ft2,0(t3)
 3c8:	003e2227          	fsw	ft3,4(t3)
 3cc:	004e2427          	fsw	ft4,8(t3)
 3d0:	005e2627          	fsw	ft5,12(t3)
 3d4:	04068863          	beqz	a3,424 <main+0xc4>
 3d8:	0843a387          	flw	ft7,132(t2)
 3dc:	a033a853          	feq.s	a6,ft7,ft3
 3e0:	04080263          	beqz	a6,424 <main+0xc4>
 3e4:	0883a807          	flw	fa6,136(t2)
 3e8:	a04828d3          	feq.s	a7,fa6,ft4
 3ec:	02088c63          	beqz	a7,424 <main+0xc4>
 3f0:	08c3a887          	flw	fa7,140(t2)
 3f4:	a112aed3          	feq.s	t4,ft5,fa7
 3f8:	020e8663          	beqz	t4,424 <main+0xc4>
 3fc:	c0000f37          	lui	t5,0xc0000
 400:	000f2023          	sw	zero,0(t5) # c0000000 <_gp+0xbfffb740>
 404:	8001a503          	lw	a0,-2048(gp) # 40c0 <bsg_y>
 408:	8041a583          	lw	a1,-2044(gp) # 40c4 <bsg_x>
 40c:	c00dfeb7          	lui	t4,0xc00df
 410:	01051813          	slli	a6,a0,0x10
 414:	00b808b3          	add	a7,a6,a1
 418:	ad1ea823          	sw	a7,-1328(t4) # c00dead0 <_gp+0xc00da210>
 41c:	0000006f          	j	41c <main+0xbc>
 420:	0000006f          	j	420 <main+0xc0>
 424:	444447b7          	lui	a5,0x44444
 428:	c0000fb7          	lui	t6,0xc0000
 42c:	44478713          	addi	a4,a5,1092 # 44444444 <_gp+0x4443fb84>
 430:	00efa023          	sw	a4,0(t6) # c0000000 <_gp+0xbfffb740>
 434:	000e2283          	lw	t0,0(t3)
 438:	004e2303          	lw	t1,4(t3)
 43c:	008e2083          	lw	ra,8(t3)
 440:	005fa023          	sw	t0,0(t6)
 444:	00ce2603          	lw	a2,12(t3)
 448:	006fa023          	sw	t1,0(t6)
 44c:	001fa023          	sw	ra,0(t6)
 450:	0903a383          	lw	t2,144(t2)
 454:	11111e37          	lui	t3,0x11111
 458:	00cfa023          	sw	a2,0(t6)
 45c:	111e0693          	addi	a3,t3,273 # 11111111 <_gp+0x1110c851>
 460:	00dfa023          	sw	a3,0(t6)
 464:	007fa023          	sw	t2,0(t6)
 468:	f9dff06f          	j	404 <main+0xa4>
