//  AMOADD barrier

//  a0 = amo lock addr (in DRAM). Initialized to 0
//  a1 = sense word addr (in DMEM).  Initialized to 1

//  void bsg_barrier_amoadd(int*, int*);

.text
.globl bsg_barrier_amoadd
bsg_barrier_amoadd:
  // t0 - sense val
  // t1 - amo result
  // t2 - check val
  // t3 - wakeup val
  // t4 - y index
  // t5 - x index

  // send amoadd
  lw t0, 0(a1)
  amoadd.w t1, t0, 0(a0)

  
  // is sense -1 or +1?
  // set wakeup val
  sub t3, x0, t0
 
  // set check val 
  blt x0, t0, bsg_barrier_amoadd_plus1

  // -1 case
  li t2, 1
  j bsg_barrier_amoadd_check

bsg_barrier_amoadd_plus1:
  // +1 case
  li t2, (bsg_tiles_X*bsg_tiles_Y)-1

bsg_barrier_amoadd_check:
  bne t2, t1, bsg_barrier_amoadd_sleep

bsg_barrier_amoadd_wakeup:
  li t4, bsg_tiles_Y-1

bsg_barrier_amoadd_wakeup_loop_y:
  li t5, bsg_tiles_X-1

bsg_barrier_amoadd_wakeup_loop_x:
  // calculate the tile-group addr for the sense val
  li t6, 0x20000000
  slli a2, t4, 24
  add t6, t6, a2
  slli a2, t5, 18
  add t6, t6, a2
  add t6, t6, a1
  sw t3, 0(t6)
  addi t5, t5, -1
  bge t5, x0, bsg_barrier_amoadd_wakeup_loop_x
  addi t4, t4, -1
  bge t4, x0, bsg_barrier_amoadd_wakeup_loop_y
  j bsg_barrier_amoadd_end


bsg_barrier_amoadd_sleep:
  lr.w t0, 0(a1)
  beq t3, t0, bsg_barrier_amoadd_end
  // we need to check this, in order to support the reservation
  // being cleared by a context switch
  lr.w.aq t0, 0(a1)
  beq t3, t0, bsg_barrier_amoadd_sleep


bsg_barrier_amoadd_end:
  ret
