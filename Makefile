SHELL := /bin/bash

BSG_IP_CORES  = ../bsg_ip_cores
VSCALE        = imports/vscale
VSCALE_SRC    = $(VSCALE)/src/main/verilog
VSCALE_INPUTS = $(VSCALE)/src/test/inputs
MODULES       = modules/v

TEST_DIR     = testbenches
TEST_MODULES = $(TEST_DIR)/common
SIM_TOP_DIR  = $(TEST_DIR)/basic
MEM_DIR      = $(TEST_DIR)/common/inputs
ROM_DIR      = $(MEM_DIR)/rom
SPMD_DIR     = $(TEST_DIR)/spmd

BSG_ROM_GEN = $(BSG_IP_CORES)/bsg_mem/bsg_ascii_to_rom.py
HEX2BIN     = $(TEST_MODULES)/py/hex2binascii.py

VLOG  = xvlog -sv
VELAB = xelab -debug typical -s top_sim
VSIM  = xsim --runall top_sim


MAX_CYCLES = 1000000
MEM_SIZE   = 8192    # size of mem to be loaded
XTILES     = 4
YTILES     = 4

DESIGN_HDRS = \
  $(addprefix $(BSG_IP_CORES)/, \
    bsg_misc/bsg_defines.v \
    bsg_noc/bsg_noc_pkg.v \
  ) \
  $(addprefix $(VSCALE_SRC)/, \
    vscale_ctrl_constants.vh \
    rv32_opcodes.vh \
    vscale_alu_ops.vh \
    vscale_md_constants.vh \
    vscale_hasti_constants.vh \
    vscale_csr_addr_map.vh \
  ) \
  $(addprefix $(MODULES)/, \
    bsg_vscale_pkg.v \
  )

DESIGN_SRCS = \
  $(addprefix $(BSG_IP_CORES)/, \
    bsg_misc/bsg_transpose.v \
    bsg_misc/bsg_crossbar_o_by_i.v \
    bsg_misc/bsg_round_robin_arb.v \
    bsg_misc/bsg_mux_one_hot.v \
    bsg_misc/bsg_encode_one_hot.v \
    bsg_misc/bsg_circular_ptr.v \
    bsg_mem/bsg_mem_1r1w.v \
    bsg_mem/bsg_mem_banked_crossbar.v \
    bsg_mem/bsg_mem_1rw_sync_mask_write_byte.v \
    bsg_mem/bsg_mem_1rw_sync.v \
    bsg_dataflow/bsg_fifo_1r1w_small.v \
    bsg_test/bsg_nonsynth_clock_gen.v \
    bsg_test/bsg_nonsynth_reset_gen.v \
    bsg_noc/bsg_mesh_router.v \
    bsg_riscv/bsg_hasti/bsg_vscale_hasti_converter.v \
  ) \
  $(addprefix $(VSCALE_SRC)/, \
    vscale_core.v \
    vscale_hasti_bridge.v \
    vscale_pipeline.v \
    vscale_ctrl.v \
    vscale_regfile.v \
    vscale_src_a_mux.v \
    vscale_src_b_mux.v \
    vscale_imm_gen.v \
    vscale_alu.v \
    vscale_mul_div.v \
    vscale_csr_file.v \
    vscale_PC_mux.v \
  ) \
  $(addprefix $(MODULES)/, \
    bsg_vscale_core.v \
    bsg_vscale_tile.v \
    bsg_vscale_tile_array.v \
  ) \
  $(addprefix $(TEST_DIR)/, \
    common/v/bsg_manycore_spmd_loader.v \
  )

setup:
	mkdir -p $(MEM_DIR)/bin
	mkdir -p $(MEM_DIR)/hex
	mkdir -p $(MEM_DIR)/rom

$(MEM_DIR)/bin/%.bin:
	python $(HEX2BIN) $(MEM_DIR)/hex/$*.hex 32 > $@

$(ROM_DIR)/bsg_rom_%.v: $(MEM_DIR)/bin/%.bin
	python $(BSG_ROM_GEN) $< bsg_rom_$* zero > $@



#----------------------------------------------------------
# SPMD tests
# ---------------------------------------------------------
include $(SPMD_DIR)/Makefrag

include $(patsubst %, $(SPMD_DIR)/%/spmd.mk, $(spmds))

INCS += -I$(SPMD_DIR)/common $(addprefix -I$(SPMD_DIR)/, $(spmds))

RISCV_GCC       ?= riscv32-unknown-elf-gcc -march=RV32IM
RISCV_GCC_OPTS  ?= -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf
RISCV_LINK      ?= $(RISCV_GCC) -T $(SPMD_DIR)/common/test.ld $(INCS)
RISCV_LINK_OPTS ?= -nostdlib -nostartfiles -ffast-math -lc -lgcc
RISCV_SIM       ?= spike --isa=RV32IM

spmd_defs = -DPREALLOCATE=0 -DHOST_DEBUG=0

VPATH += $(SPMD_DIR)/common $(addprefix $(SPMD_DIR)/, $(spmds))

%.o: %.c
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $(spmd_defs) \
		-c $(INCS) $< -o $@

%.o: %.S
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $(spmd_defs) -D__ASSEMBLY__=1 \
		-c $(INCS) $< -o $@

$(MEM_DIR)/hex/%.hex: %.riscv
	elf2hex 16 8192 $< > $@

# runs spike simulations
riscv-spmd-sim: $(addsuffix .riscv, $(spmds))
	$(RISCV_SIM) $<

load-spmd-inputs: $(addprefix $(MEM_DIR)/hex/, $(addsuffix .hex, $(spmds)))

vivado-spmd-tests: load-spmd-inputs $(foreach x, $(spmds), vivado_spmd.$(x))

vivado_spmd.%: $(ROM_DIR)/bsg_rom_%.v
	@echo testing $*...
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(ROM_DIR)/bsg_rom_$*.v $(SIM_TOP_DIR)/test_bsg_vscale_tile_array.v \
		-d SPMD=$* -d XTILES=$(XTILES) -d YTILES=$(YTILES) -d MEM_SIZE=$(MEM_SIZE)
	$(VELAB) test_bsg_vscale_tile_array | grep -v Compiling
	$(VSIM)



#----------------------------------------------------------
# Instruction tests
# ---------------------------------------------------------
include $(VSCALE)/Makefrag

load_asm.%:
	cp $(VSCALE_INPUTS)/$*.hex $(MEM_DIR)/hex/$(subst -,_,$*).hex

vivado-tile-array-asm-tests: setup $(foreach x, $(RV32_TESTS), load_asm.$(x)) $(foreach x, $(subst -,_,$(RV32_TESTS)), vivado_tile_array_asm.$(x))

vivado_tile_array_asm.%: $(ROM_DIR)/bsg_rom_%.v
	@echo testing $*...
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(ROM_DIR)/bsg_rom_$*.v $(SIM_TOP_DIR)/test_bsg_vscale_tile_array.v -d SPMD=$*
	$(VELAB) test_bsg_vscale_tile_array | grep -v Compiling
	$(VSIM)

vivado-tile-asm-tests: setup $(foreach x, $(RV32_TESTS), load_asm.$(x)) $(foreach x, $(RV32_TESTS), vivado_tile_asm.$(x)) 

vivado_tile_asm.%:
	@echo testing $*...
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(SIM_TOP_DIR)/test_bsg_vscale_tile.v
	$(VELAB) test_bsg_vscale_tile
	$(VSIM) --testplusarg max-cycles=$(MAX_CYCLES) --testplusarg loadmem=$(MEM_DIR)/hex/$*.hex



clean:
	rm -rf $(MEM_DIR)/hex/* $(MEM_DIR)/bin/* $(MEM_DIR)/rom/* *.o *.riscv *.jou *.log *.wdb *.pb xsim.dir

