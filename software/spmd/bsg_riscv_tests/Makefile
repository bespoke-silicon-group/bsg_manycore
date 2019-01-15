bsg_tiles_X= 2
bsg_tiles_Y= 2

include ../Makefile.include

RVTEST_ISAs = rv32ui rv32um rv32ua
RVTEST_DIR = $(BSG_MANYCORE_DIR)/imports/riscv-tests/isa

# Add source directories to the search path
RVTEST_ASM_DIRs = $(foreach test_isa, $(RVTEST_ISAs), $(RVTEST_DIR)/$(test_isa))
vpath %.S $(RVTEST_ASM_DIRs)

# Current directory has the modified header "riscv_test.h", which 
# will override the original one.
RVTEST_INCS = -I. -I$(RVTEST_DIR)/macros/scalar

INCS += $(RVTEST_INCS)
RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles

%.riscv:  %.o
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)

%.run: PROG_NAME=$(basename $@)

# Import list of tests from riscv-tests repo. Below Makefrags have tests listed as
# variables in the format "<test_isa>_sc_tests"
include $(foreach test_asm_dir, $(RVTEST_ASM_DIRs), $(test_asm_dir)/Makefrag)

RUNS = $(foreach test_isa, $(RVTEST_ISAs)\
		   , $(foreach test, $($(test_isa)_sc_tests)\
				 , $(RVTEST_DIR)/$(test_isa)/$(test).run))

all: $(RUNS)
	$(warning Finished running: $(RUNS))

include ../../mk/Makefile.tail_rules
