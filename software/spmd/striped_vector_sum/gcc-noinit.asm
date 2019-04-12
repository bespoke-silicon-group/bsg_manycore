8000040c <vector_sum>:
8000040c:	srli	a4,a0,0x1f ; a4 = bsg_id >> 31; 0
80000410:	add	a5,a0,a4   ; a5 = bsg_id
80000414:	add	a3,a4,a0   ; a3 = 0
80000418:	andi	a5,a5,1    ; a5 = bsg_id & 1 (y)
8000041c:	slli	a7,a0,0x2  ; a7 = bsg_id  * 4
80000420:	sub	a5,a5,a4   ; a5 = y - 0
80000424:	srai	a3,a3,0x1  ; a3 = 0
80000428:	mv	a1,a0      ; a1 = bsg_id
8000042c:	slli	a3,a3,0x12 ; a3 = 0 << 12
80000430:	slli	a5,a5,0x18 ; a5 = y << 18
80000434:	addi	a0,a7,1    ; a0 = bsg_id * 4 + 1
80000438:	lui	a4,0x1
8000043c:	addi	a4,a4,20 # a4 = 1014 <A> 
80000440:	or	a5,a5,a3   ; a5 = y << 18 | 0 << 12
80000444:	slli	a6,a1,0x4  ; a6 = bsg_id << 4
80000448:	lui	a3,0x20000 ; a3 = 0x20000000
8000044c:	slli	a0,a0,0x2  ; a0 = (bsg_id * 4 + 1) * 4
80000450:	addi	a2,a7,2    ; a2 = bsg_id * 4 + 2
80000454:	or	a5,a5,a3
80000458:	add	a6,a4,a6
8000045c:	add	a0,a4,a0
80000460:	slli	a2,a2,0x2
80000464:	addi	a3,a7,3
80000468:	or	a0,a0,a5
8000046c:	or	a6,a6,a5
80000470:	add	a2,a4,a2
80000474:	slli	a3,a3,0x2
80000478:	lw	a6,0(a6) # 1000000 <_gp+0xffe800>
8000047c:	or	a2,a2,a5
80000480:	lw	t1,0(a0)
80000484:	add	a3,a4,a3
80000488:	lw	a0,0(a2)
8000048c:	or	a3,a3,a5
80000490:	lw	a3,0(a3) # 20000000 <_gp+0x1fffe800>
80000494:	add	a2,a6,t1
80000498:	addi	a4,a4,64
8000049c:	add	a2,a2,a0
800004a0:	add	a4,a4,a7
800004a4:	add	a2,a3,a2
800004a8:	or	a5,a4,a5
800004ac:	lui	a0,0x80001
800004b0:	sw	a2,0(a5)
800004b4:	addi	a0,a0,1620 # 80001654 <_bsg_dram_end_addr+0xffffff9c>
800004b8:	j	80000890 <bsg_printf>

80001600 <main>:
80001600:	addi	sp,sp,-16
80001604:	sw	ra,12(sp)
80001608:	sw	s0,8(sp)
8000160c:	sw	s1,4(sp)
80001610:	jal	ra,800004bc <bsg_set_tile_x_y>
80001614:	lui	s1,0x1
80001618:	lw	a5,16(s1) # 1010 <__bsg_x>
8000161c:	lui	s0,0x1
80001620:	lw	a0,12(s0) # 100c <__bsg_y>
80001624:	slli	a5,a5,0x1
80001628:	add	a0,a5,a0
8000162c:	jal	ra,8000040c <vector_sum>
80001630:	lw	a5,16(s1)
80001634:	li	a4,1
80001638:	beq	a5,a4,80001640 <main+0x40>
8000163c:	j	8000163c <main+0x3c>
80001640:	lw	a4,12(s0)
80001644:	bnez	a4,8000163c <main+0x3c>
80001648:	lui	a4,0x4004f
8000164c:	sw	a5,-1328(a4) # 4004ead0 <_gp+0x4004d2d0>
80001650:	j	80001650 <main+0x50>
80001654:	lw	s6,48(sp)
80001656:	lui	s0,0x9
80001658:	jal	800016fe <_bsg_dram_end_addr+0x46>
8000165a:	jal	80001688 <main+0x88>
