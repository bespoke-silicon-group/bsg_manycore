
main.riscv:     file format elf32-littleriscv


Disassembly of section .text:

00000100 <user_trap_entry>:
 100:	00000793          	li	a5,0
 104:	78079073          	csrw	mtohost,a5
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
 144:	78079073          	csrw	mtohost,a5
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
 184:	78079073          	csrw	mtohost,a5
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
 1c4:	78079073          	csrw	mtohost,a5
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
 2b8:	54c18193          	addi	gp,gp,1356 # 4800 <_gp>
 2bc:	00004217          	auipc	tp,0x4
 2c0:	d8b20213          	addi	tp,tp,-629 # 4047 <_end+0x3f>
 2c4:	fc027213          	andi	tp,tp,-64
 2c8:	00008137          	lui	sp,0x8
 2cc:	ffc10113          	addi	sp,sp,-4 # 7ffc <_gp+0x37fc>
 2d0:	0680006f          	j	338 <main>
 2d4:	10000073          	eret

000002d8 <bsg_set_tile_x_y>:
 2d8:	80418293          	addi	t0,gp,-2044 # 4004 <bsg_x>
 2dc:	800007b7          	lui	a5,0x80000
 2e0:	00f2e533          	or	a0,t0,a5
 2e4:	00052023          	sw	zero,0(a0)
 2e8:	80018313          	addi	t1,gp,-2048 # 4000 <bsg_y>
 2ec:	00f366b3          	or	a3,t1,a5
 2f0:	0006a023          	sw	zero,0(a3)
 2f4:	8041a383          	lw	t2,-2044(gp) # 4004 <bsg_x>
 2f8:	fe03cee3          	bltz	t2,2f4 <bsg_set_tile_x_y+0x1c>
 2fc:	8001a883          	lw	a7,-2048(gp) # 4000 <bsg_y>
 300:	fe08cee3          	bltz	a7,2fc <bsg_set_tile_x_y+0x24>
 304:	8041ae83          	lw	t4,-2044(gp) # 4004 <bsg_x>
 308:	020e9663          	bnez	t4,334 <bsg_set_tile_x_y+0x5c>
 30c:	8001af83          	lw	t6,-2048(gp) # 4000 <bsg_y>
 310:	020f9263          	bnez	t6,334 <bsg_set_tile_x_y+0x5c>
 314:	00052023          	sw	zero,0(a0)
 318:	0006a023          	sw	zero,0(a3)
 31c:	a00007b7          	lui	a5,0xa0000
 320:	00f2e633          	or	a2,t0,a5
 324:	00100293          	li	t0,1
 328:	00562023          	sw	t0,0(a2)
 32c:	00f36533          	or	a0,t1,a5
 330:	00052023          	sw	zero,0(a0)
 334:	00008067          	ret

Disassembly of section .text.startup:

00000338 <main>:
 338:	8041a703          	lw	a4,-2044(gp) # 4004 <bsg_x>
 33c:	c0000337          	lui	t1,0xc0000
 340:	44444537          	lui	a0,0x44444
 344:	01d71293          	slli	t0,a4,0x1d
 348:	0062e3b3          	or	t2,t0,t1
 34c:	44450593          	addi	a1,a0,1092 # 44444444 <_gp+0x4443fc44>
 350:	00b3a023          	sw	a1,0(t2)
 354:	00000513          	li	a0,0
 358:	00008067          	ret
