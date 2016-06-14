find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

$(warning $(BSG_MANYCORE_DIR))

TEST_DIR        = $(BSG_MANYCORE_DIR)/testbenches
RISCV_INPUT_DIR = $(TEST_DIR)/common/riscv_tests

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.paths
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.verilog
include $(TEST_DIR)/Makefrag

bsg_tiles_X = 1
bsg_tiles_Y = 1

HEX2BIN       = $(BSG_MANYCORE_DIR)/software/py/hex2binascii.py
BSG_ROM_GEN   = $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py
RISCV_ELF2HEX = $(RISCV_BIN_DIR)/elf2hex

instr-tests: $(foreach x,$(subst -,_,$(RV32_TESTS)),$(x).run)

single: rv32ui_p_add.run

%.bin: %.hex
	python $(HEX2BIN) $*.hex 32 > $@

%.hex: %.riscv
	$(RISCV_BIN_DIR)/elf2hex 16 8192 $< > $@

%.riscv:
	make -C $(RISCV_INPUT_DIR)/isa/ $*
	mv $(RISCV_INPUT_DIR)/isa/$* $*.riscv

%.dis: %.riscv
	$(RISCV_BIN_DIR)/riscv64-unknown-elf-objdump -D $< > $@

clean:
	rm -rf xelab.* xvlog.* xsim* webtalk* *.wdb *.Xil *.riscv *.bin *.hex *.dis
