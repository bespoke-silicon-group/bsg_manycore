SHELL = /bin/bash

include Makefrag

BSG_IP_CORES   = ../bsg_ip_cores
VSCALE_SRC_DIR = imports/vscale/src/main/verilog
MODULES        = modules/v

TEST_DIR       = testbenches
MEM_DIR        = testbenches/common/inputs

MAX_CYCLES     = 1000000

DESIGN_HDRS = \
  $(addprefix $(BSG_IP_CORES)/, \
    bsg_misc/bsg_defines.v \
    bsg_noc/bsg_noc_pkg.v \
  ) \
  $(addprefix $(VSCALE_SRC_DIR)/, \
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
  $(addprefix $(VSCALE_SRC_DIR)/, \
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

SIM_TOPS = \
  $(TEST_DIR)/basic/test_bsg_vscale_tile.v \
  $(TEST_DIR)/basic/test_bsg_vscale_tile_array.v

run-tile-tests: compile $(foreach x, $(RV32_TESTS), run_tile.$(x)) 
run-tile-array-tests: compile $(foreach x, $(RV32_TESTS), run_tile_array.$(x)) 

compile: initial $(DESIGN_HDRS) $(DESIGN_SRCS) $(SIM_TOPS)
	vlog -sv -mfcu -work ./work -suppress 2583 $(DESIGN_HDRS) $(DESIGN_SRCS) $(SIM_TOPS)

initial:
	rm -rf work/
	vlib work
	vmap work ./work

run_tile.%:
	vsim -batch -lib ./work -suppress 8315 test_bsg_vscale_tile +max-cycles=$(MAX_CYCLES) +loadmem=$(MEM_DIR)/$*.hex -do "run -all; quit -f"

run_tile_array.%:
	vsim -batch -lib ./work -suppress 8315 test_bsg_vscale_tile_array +hexfile=$(MEM_DIR)/$*.hex -do "run -all; quit -f"
