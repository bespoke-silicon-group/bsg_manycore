#
#		Makefile
#


bsg_tiles_X = 4
bsg_tiles_Y = 4

TEST_NAME ?= hello_manycore

# build setting
RISCV_BIN_DIR = $(BSG_MANYCORE_DIR)/software/riscv-tools/riscv-install/bin
RISCV_GCC = $(RISCV_BIN_DIR)/riscv32-unknown-elf-gcc
RISCV_OBJCOPY = $(RISCV_BIN_DIR)/riscv32-unknown-elf-objcopy

RISCV_GCC_OPT = -march=rv32ima -static -std=gnu99 -ffast-math -fno-common -fno-builtin-printf -O2
RISCV_GCC_EXTRA_OPT = -Dbsg_tiles_X=$(bsg_tiles_X) -Dbsg_tiles_Y=$(bsg_tiles_Y) -DPREALLOCATE=0 -DHOST_DEBUG=0
RISCV_GCC_INC = -I$(BSG_MANYCORE_DIR)/software/spmd/common/
RISCV_GCC_INC += -I$(BSG_MANYCORE_DIR)/software/bsg_manycore_lib

LD_FILE = $(BSG_MANYCORE_DIR)/software/spmd/common/test.ld
OBJECT_FILES = main.o bsg_set_tile_x_y.o bsg_printf.o crt.o


.PHONY: dve sim all clean

all: sim

# GCC rules

main.o:
	$(RISCV_GCC) $(RISCV_GCC_OPT) $(RISCV_GCC_INC) $(RISCV_GCC_EXTRA_OPT) \
	-c test/$(TEST_NAME)/main.c -o main.o

bsg_set_tile_x_y.o:
	$(RISCV_GCC) $(RISCV_GCC_OPT) $(RISCV_GCC_INC) $(RISCV_GCC_EXTRA_OPT) \
	-c $(BSG_MANYCORE_DIR)/software/bsg_manycore_lib/bsg_set_tile_x_y.c -o $@

bsg_printf.o:
	$(RISCV_GCC) $(RISCV_GCC_OPT) $(RISCV_GCC_INC) $(RISCV_GCC_EXTRA_OPT) \
	-c $(BSG_MANYCORE_DIR)/software/bsg_manycore_lib/bsg_printf.c -o $@

crt.o:
	$(RISCV_GCC) $(RISCV_GCC_OPT) $(RISCV_GCC_INC) $(RISCV_GCC_EXTRA_OPT) -D__ASSEMBLY__=1 \
	-c $(BSG_MANYCORE_DIR)/software/spmd/common/crt.S -o $@

main.riscv: $(OBJECT_FILES)
	$(RISCV_GCC) -T $(LD_FILE) $(OBJECT_FILES) -o $@ \
	-march=rv32ima -nostdlib -nostartfiles -ffast-math -lc -lgcc -L .

main_dmem.mem: main.riscv
	$(RISCV_OBJCOPY) -O verilog -R .text $< $@

main_dram.mem: main.riscv
	$(RISCV_OBJCOPY) -O verilog -j .text $< $@;
	sed -i -e "1d" $@;

# VCS rules
VCS_HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'
VCS_OPT = +v2k -R -sverilog -full64 -debug_pp -timescale=1ps/1ps +vcs+vcdpluson
VCS_LINT = +lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS

VCS_INC = +incdir+$(BSG_IP_CORES_DIR)/bsg_misc/
VCS_INC += +incdir+$(BSG_IP_CORES_DIR)/bsg_cache/
VCS_INC += +incdir+$(BSG_IP_CORES_DIR)/bsg_noc/
VCS_INC += +incdir+$(BSG_MANYCORE_DIR)/v/
VCS_INC += +incdir+$(BSG_MANYCORE_DIR)/v/vanilla_bean

DRAM_SHIFT_ADDR = 0x80000000
find-section-addr = $(shell nm --radix=d main.riscv | grep $(1) | awk '{print $$1}')
find-shifted-section-addr = $(shell echo $$(( $(call find-section-addr, $(1)) - $(2) )))

VCS_DEFINES = +define+_dram_init_file_name='"main_dram.mem"'
VCS_DEFINES += +define+_dmem_init_file_name='"main_dmem.mem"'
VCS_DEFINES += +define+_bsg_data_start_addr=$(call find-section-addr, _bsg_data_start_addr)
VCS_DEFINES += +define+_bsg_data_end_addr=$(call find-section-addr, _bsg_data_end_addr)
VCS_DEFINES += +define+_bsg_dram_start_addr=$(call find-shifted-section-addr, _bsg_dram_start_addr, $(DRAM_SHIFT_ADDR))
VCS_DEFINES += +define+_bsg_dram_end_addr=$(call find-shifted-section-addr, _bsg_dram_end_addr, $(DRAM_SHIFT_ADDR))

sim: main_dram.mem main_dmem.mem
	vcs $(VCS_OPT) $(VCS_LINT) $(VCS_INC) -f sv.include \
	$(VCS_DEFINES) -l vcs.log \
	| $(VCS_HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles
	rm -rf csrc
	rm -rf simv.daidir simv.vdb
	rm -rf stack.info*
	rm -f ucli.key vcdplus.vpd simv *.tar.gz vcs.log
	rm -f *.o *.riscv *.mem
