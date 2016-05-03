SHELL := /bin/bash

BSG_IP_CORES  = ../bsg_ip_cores
VSCALE        = imports/vscale
VSCALE_SRC    = $(VSCALE)/src/main/verilog
VSCALE_INPUTS = $(VSCALE)/src/test/inputs
MODULES       = modules/v

TEST_DIR      = testbenches
TEST_MODULES  = $(TEST_DIR)/common
SIM_TOP_DIR   = $(TEST_DIR)/basic
MEM_DIR       = $(TEST_DIR)/common/inputs
ROM_DIR       = $(MEM_DIR)/rom

BSG_ROM_GEN   = $(BSG_IP_CORES)/bsg_mem/bsg_ascii_to_rom.py
HEX2BIN       = $(TEST_MODULES)/py/hex2binascii.py

VLOG = xvlog -sv
VELAB = xelab -debug typical -s top_sim
VSIM = xsim --runall top_sim

include $(VSCALE)/Makefrag

MAX_CYCLES     = 1000000

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
	python $(HEX2BIN) $(subst _,-,$(MEM_DIR)/hex/$*.hex) 32 > $@

$(ROM_DIR)/bsg_rom_%.v: $(MEM_DIR)/bin/%.bin
	python $(BSG_ROM_GEN) $< bsg_rom_$* zero > $@

# loads $(MEM_DIR)/hex exclusively with asm-tests
load-asm-inputs:
	rm -rf $(MEM_DIR)/hex
	mkdir -p $(MEM_DIR)/hex
	cp $(VSCALE_INPUTS)/*.hex $(MEM_DIR)/hex

modelsim-init:
	rm -rf work/
	vlib work
	vmap work ./work

modelsim-tile-array-asm-tests: load-asm-inputs $(foreach x, $(subst -,_,$(RV32_TESTS)), modelsim_tile_array_asm.$(x))

modelsim_tile_array_asm.%: $(ROM_DIR)/bsg_rom_%.v
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(ROM_DIR)/bsg_rom_$*.v $(SIM_TOP_DIR)/test_bsg_vscale_tile_array.v -d SPMD=$*
	$(VELAB) test_bsg_vscale_tile_array | grep -v Compiling
	$(VSIM)

modelsim-tile-asm-tests: load-asm-inputs $(foreach x, $(RV32_TESTS), modelsim_tile_asm.$(x)) 

modelsim_tile_asm.%:
	$(VLOG) $(DESIGN_HDRS) $(DESIGN_SRCS) $(SIM_TOP_DIR)/test_bsg_vscale_tile.v
	$(VELAB) test_bsg_vscale_tile
	$(VSIM) --testplusarg max-cycles=$(MAX_CYCLES) --testplusarg loadmem=$(MEM_DIR)/hex/$*.hex


clean:
	rm -rf $(MEM_DIR)/* *.jou *.log *.wdb *.pb xsim.dir



