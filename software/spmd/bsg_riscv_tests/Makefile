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
RISCV_LINK_OPTS = -march=rv32ima -nostdlib -nostartfiles

%.riscv:  %.o
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)

%.run: PROG_NAME=$(basename $@)

# All instruction tests in the ISA
#
# Import list of tests from riscv-tests repo. Below Makefrags have tests listed as
# variables in the format "<test_isa>_sc_tests"
include $(foreach test_asm_dir, $(RVTEST_ASM_DIRs), $(test_asm_dir)/Makefrag)

ALL_RUNS = $(foreach test_isa, $(RVTEST_ISAs)\
               , $(foreach test, $($(test_isa)_sc_tests)\
                     , $(RVTEST_DIR)/$(test_isa)/$(test).run))

all: $(ALL_RUNS)
	$(warning Finished running: $(ALL_RUNS))

# Selected instrcution tests
#
# Run following instruction tests
TEST_INSTRS = \
	add addi \
	and andi \
	auipc \
	beq bge bgeu blt bltu bne \
	fence_i \
	jal jalr \
	lb lbu lh lhu lw \
	lui \
	or ori \
	sb sh sw \
	sll slli \
	slt slti sltiu sltu \
	sra srai \
	srl srli \
	sub \
	xor xori \
	div divu \
	mul mulh mulhsu mulhu \
	rem remu \

selected: $(foreach instr, $(TEST_INSTRS), $(instr).run)
	$(warning Finished running: $(TEST_INSTRS))

include ../../mk/Makefile.tail_rules
