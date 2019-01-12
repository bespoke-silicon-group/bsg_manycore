bsg_tiles_X= 2
bsg_tiles_Y= 2

include ../Makefile.include

RVTEST_DIR = $(BSG_MANYCORE_DIR)/imports/riscv-tests/isa
RVTEST_MACROS_DIR = $(RVTEST_DIR)/macros/scalar

TEST_ISAs = rv32ui rv32um rv32ua
TEST_ASM_DIRs = $(foreach test_isa, $(TEST_ISAs), $(RVTEST_DIR)/$(test_isa))

# Import list of tests for each isa. Below Makefrags have tests listed as variables in
# the format "<test_isa>_sc_tests"
include $(foreach test_asm_dir, $(TEST_ASM_DIRs), $(test_asm_dir)/Makefrag)

RUNS = $(foreach test_isa, $(TEST_ISAs)\
		   , $(foreach test, $($(test_isa)_sc_tests)\
				 , $(RVTEST_DIR)/$(test_isa)/$(test).run))

$(warning Running $(RUNS))
all: $(RUNS)

%.run: PROG_NAME=$(basename $@)

INCS += -I$(RVTEST_MACROS_DIR) -I.
RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles 

%.riscv:  %.o
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd
