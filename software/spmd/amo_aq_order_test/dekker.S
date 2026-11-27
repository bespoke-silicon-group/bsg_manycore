// The timed halves of the test in main.c. Each sets a flag with an AMO, then loads another flag.
//
//   int dekker_main_*(int *go, int *mine, int *other);
//     Wakes the partner with a store to go, waits MAIN_DELAY cycles, then runs the two instructions.
//   int dekker_partner_*(int *go, int *mine, int *other, int delay);
//     Sleeps until go is written, waits delay cycles, then runs the two instructions.
//
// Both return the value loaded from other.
//
//   plain : amoswap.w
//   aq1   : amoswap.w.aq, with its destination written by the instruction before it
//   aq2   : amoswap.w.aq, with its destination written two instructions before it

#define MAIN_DELAY 20
#define MAX_DELAY  24

.macro SET_AND_LOAD amo, gap
  li   t0, 1
  .rept \gap
  nop
  .endr
  \amo t0, t0, (a1)
  lw   a0, 0(a2)
  ret
.endm

.macro DEKKER_MAIN name, amo, gap
  .globl \name
\name:
  li   t1, 1
  sw   t1, 0(a0)
  .rept MAIN_DELAY
  nop
  .endr
  SET_AND_LOAD \amo, \gap
.endm

.macro DEKKER_PARTNER name, amo, gap
  .globl \name
\name:
  la   t1, 2f
  slli a3, a3, 2
  sub  t1, t1, a3       // run only the last delay nops
  lr.w t2, (a0)
  bnez t2, 1f           // already woken
  lr.w.aq t2, (a0)      // sleep until go is written
1:
  jr   t1
  .rept MAX_DELAY
  nop
  .endr
2:
  SET_AND_LOAD \amo, \gap
.endm

  .text
  DEKKER_MAIN    dekker_main_plain,    amoswap.w,    1
  DEKKER_MAIN    dekker_main_aq1,      amoswap.w.aq, 0
  DEKKER_MAIN    dekker_main_aq2,      amoswap.w.aq, 1
  DEKKER_PARTNER dekker_partner_plain, amoswap.w,    1
  DEKKER_PARTNER dekker_partner_aq1,   amoswap.w.aq, 0
  DEKKER_PARTNER dekker_partner_aq2,   amoswap.w.aq, 1
