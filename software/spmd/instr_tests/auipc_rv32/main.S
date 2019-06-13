// Consice program to test PC relative data access from 
// DRAM. Test 1 uses abosulte addressing and should most 
// probably pass. Test 2 uses PC relative addressing and 
// would only pass if .dram data address relocations by
// linker are correct.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define TEST_DATA0 (0xdeadbeef)

.text

/* Test 1: Absolute addressing */
test_1:
  // load
  lui a0, %hi(dram_var);
  addi a0, a0, %lo(dram_var);
  lw s0, 0(a0);
  
  // check
  li s2, TEST_DATA0;
  beq s2, s0, 1f;
  li ra, 0x1; // ra holds failed test number
  j fail;
  1:

/* Test 2: PC relative addressing (auipc) */
test_2:
  // load
  la a0, dram_var;
  lw s0, 0(a0);
  
  // check
  li s2, TEST_DATA0;
  beq s2, s0, 1f;
  li ra, 0x2;
  j fail;
  1:

pass:
  bsg_asm_finish(IO_X_INDEX, 0x0);

fail:
  bsg_asm_fail_reg(IO_X_INDEX, ra); // fail displaying test number


// For objcopy to copy this section we have to make this
// an allocatable section by flags below
.section .dram, "aw"

dram_var:
  .word TEST_DATA0
