# This file contains a list of non-synthesizable files used in manycore
# simulation. These augment the sythesizable files in core.include.

VINCLUDES += $(BASEJUMP_STL_DIR)/testing/bsg_dmc/lpddr_verilog_model

VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_mem_cfg_pkg.v
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_profile_pkg.v

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_axi_mem.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_mem_infinite.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_mask_write_byte_assoc.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_assoc.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_clock_gen.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_reset_gen.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_cycle_counter.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out_full.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_1_to_n.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_one_fifo.v

VSOURCES += $(BASEJUMP_STL_DIR)/testing/bsg_dmc/lpddr_verilog_model/mobile_ddr.v

CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/HBM.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/Config.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/StatType.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/Controller.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/ALDRAM.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/imports/ramulator/src/TLDRAM.cpp
CSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_ramulator_hbm.cpp

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_ramulator_hbm.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_test_dram_channel.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_ramulator_hbm.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_ramulator_hbm_rx.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_ramulator_hbm_tx.v

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/instr_trace.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_trace.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_non_blocking_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/infinite_mem_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_spmd_loader.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_monitor.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/spmd_testbench.v

