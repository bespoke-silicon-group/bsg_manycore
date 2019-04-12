8000065c <vector_sum>:
8000065c:	addi	sp,sp,-16
80000660:	sw	ra,12(sp)
80000664:	mv	a6,a0      ; a6 = bsg_id
80000668:	lui	a0,0x1     ; a0 = 0x1000
8000066c:	addi	a0,a0,32   ; a0 = 1020 <A>
80000670:	slli	a1,a6,0x4  ; a1 = bsg_id * 16
80000674:	add	t4,a1,a0   ; t4 = &A[bsg_id][0]
80000678:	lui	a0,0x1     ; a0 = 0x1000
8000067c:	addi	a0,a0,32   ; a0 = 0x1020 <A>
80000680:	lui	t1,0x1000  ; t1 = 0x1000000 ; tile_x /tile_y mask
80000684:	lui	t0,0x40    ; t0 = 0x40000
80000688:	lui	a1,0x40000 ; a1 = 0x40000000
8000068c:	addi	t3,a1,-4   ; t3 = 3ffffffc <_gp+0x3fffe7e8> (x / 4 * 4 mask)
80000690:	lui	a7,0x20000 ; a7 = 0x20000000 (REMOTE_EPA_PREFIX)
80000694:	li	t2,16      ; t2 = 0x16
80000698:	li	a1,0       ; a1 = 0 ; i -- loop variable
8000069c:	li	a2,0       ; a2 = 0 ; accum
800006a0:	add	a5,t4,a1   ; a5 = &A[bsg_id][i] (loop start)
800006a4:	sub	a5,a5,a0   ; a5 = &A[bsg_id][i] - start_ptr   (diff)
800006a8:	slli	a4,a5,0x16 ;
800006ac:	and	a4,a4,t1   ;
800006b0:	slli	a3,a5,0xf  ;
800006b4:	and	a3,a3,t0   ;
800006b8:	or	a3,a3,a4   ; a3 = diff & 0x108
800006bc:	srli	a4,a5,0x2  ; a4 = diff / 4                    (index)
800006c0:	and	a4,a4,t3   ;
800006c4:	add	a4,a4,a0   ; a4 = start_ptr + (index / 4) * 4 (local)
800006c8:	or	a3,a3,a4   ; a3 = diff & 0x108 | a4
800006cc:	or	a3,a3,a7   ; a3 = val | REMOTE_EPA_PREFIX
800006d0:	lw	a3,0(a3) # 1000000 <_gp+0xffe7ec>
800006d4:	add	a2,a3,a2   ; increment accumulate
800006d8:	addi	a1,a1,4    ; increment i
800006dc:	bne	a1,t2,800006a0 <vector_sum+0x44>
800006e0:	lui	a1,0x1    ;
800006e4:	addi	a1,a1,96  ; a1 = 0x1060 <B>
800006e8:	slli	a3,a6,0x2 ; a3 = bsg_id * 4
800006ec:	add	a1,a3,a1  ; a1 = B[bsg_id]
800006f0:	sub	a1,a1,a0  ; a1 = B[bsg_id] - _striped_data_start(0x1020)
800006f4:	slli	a3,a1,0x16;
800006f8:	and	a3,a3,t1  ;a3 = diff & 0x100
800006fc:	slli	a5,a1,0xf ;
80000700:	and	a5,a5,t0  ;
80000704:	or	a3,a5,a3  ; a3 = diff & 0x108
80000708:	srli	a1,a1,0x2 ; a1 = diff / 4     (index)
8000070c:	and	a1,a1,t3  ; a1 = index / 4 * 4
80000710:	add	a0,a1,a0  ; a0 = start + a1   (local_addr)
80000714:	or	a0,a3,a0  ; a0 = tile_x,y | local_addr
80000718:	or	a0,a0,a7  ; a0 |= REMOTE_EPA_PREFIX
8000071c:	sw	a2,0(a0)
80000720:	lui	a0,0x80002 ; a0 = 0x80002000
80000724:	addi	a0,a0,-1316 # 80001adc <_bsg_dram_end_addr+0xffffffa3>
80000728:	mv	a1,a6
8000072c:	jal	ra,80000884 <bsg_printf>
80000730:	lw	ra,12(sp)
80000734:	addi	sp,sp,16
80000738:	ret

8000073c <main>:
8000073c:	addi	sp,sp,-16
80000740:	sw	ra,12(sp)
80000744:	sw	s1,8(sp)
80000748:	sw	s2,4(sp)
8000074c:	jal	ra,80000794 <bsg_set_tile_x_y>
80000750:	lui	s1,0x1
80000754:	lw	a0,0(s1) # 1000 <__bsg_x>
80000758:	slli	a0,a0,0x1
8000075c:	lui	s2,0x1
80000760:	lw	a1,4(s2) # 1004 <__bsg_y>
80000764:	add	a0,a0,a1
80000768:	jal	ra,8000065c <vector_sum>
8000076c:	lw	a1,0(s1)
80000770:	li	a0,1
80000774:	bne	a1,a0,80000790 <main+0x54>
80000778:	lw	a1,4(s2)
8000077c:	bnez	a1,80000790 <main+0x54>
80000780:	lui	a1,0x4004f
80000784:	addi	a1,a1,-1328 # 4004ead0 <_gp+0x4004d2bc>
80000788:	sw	a0,0(a1)
8000078c:	j	8000078c <main+0x50>
80000790:	j	80000790 <main+0x54>
