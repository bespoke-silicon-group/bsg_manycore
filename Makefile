SHELL := /bin/bash

BSG_IP_CORES  = ../bsg_ip_cores
VSCALE        = imports/vscale
VSCALE_INPUTS = $(VSCALE)/src/test/inputs
MODULES       = modules/v

TEST_DIR     = testbenches
TEST_MODULES = $(TEST_DIR)/common
SIM_TOP_DIR  = $(TEST_DIR)/basic
SPMD_DIR     = $(TEST_DIR)/spmd


MAX_CYCLES     = 1000000

#----------------------------------------------------------
# SPMD tests
# ---------------------------------------------------------
spmds = \
	hello

include $(patsubst %, $(SPMD_DIR)/%/spmd.mk, $(spmds))

INCS += -I$(SPMD_DIR)/common $(addprefix -I$(SPMD_DIR)/, $(spmds))

#RISCV_GCC       ?= riscv32-unknown-elf-gcc -march=RV32IM

#RISCV_GCC       ?= ../../riscv-tools/riscv-install/bin/riscv64-unknown-elf-gcc

RISCV_LINK      ?= $(RISCV_GCC) -T $(SPMD_DIR)/common/test.ld $(INCS)

RISCV_SIM       ?= spike --isa=RV32IM



VPATH += $(SPMD_DIR)/common $(addprefix $(SPMD_DIR)/, $(spmds))

# runs spike simulations
riscv-spmd-sim: $(addsuffix .riscv, $(spmds))
	$(RISCV_SIM) $<

load-spmd-inputs: $(addprefix $(MEM_DIR)/hex/, $(addsuffix .hex, $(spmds)))

vivado-spmd-tests: load-spmd-inputs $(foreach x, $(spmds), vivado_spmd.$(x))

vivado_spmd.%: bsg_rom_%.v
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) bsg_rom_$*.v $(SIM_TOP_DIR)/test_bsg_vscale_tile_array.v -d SPMD=$*
	$(VELAB) test_bsg_vscale_tile_array | grep -v Compiling
	$(VSIM)

