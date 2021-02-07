# This file contains a list of non-synthesizable files used in manycore
# simulation. These augment the sythesizable files in core.include.

VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_mem_cfg_pkg.v
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_network_cfg_pkg.v
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_profile_pkg.v
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_test/bsg_dramsim3_pkg.v

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_axi_mem.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_mem_infinite.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_clock_gen.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_reset_gen.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_cycle_counter.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out_full.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_1_to_n.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_one_fifo.v


VSOURCES += $(BASEJUMP_STL_DIR)/bsg_fsb/bsg_fsb_node_trace_replay.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_tag/bsg_tag_trace_replay.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_tag/bsg_tag_master.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_rx.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_dram_ctrl_tx.v

VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/hash_function_reverse.v
VSOURCES += $(BSG_MANYCORE_DIR)/v/vanilla_bean/bsg_cache_to_axi_hashed.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_rx.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_axi_tx.v

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1r1w_sync_mask_write_byte_dma.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1r1w_sync_dma.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma.v
CSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_dma.cpp

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3_map.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3_unmap.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_dramsim3.cpp
CSOURCES +=  $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/bankstate.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/channel_state.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/command_queue.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/common.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/configuration.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/controller.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/dram_system.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/hmc.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/memory_system.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/refresh.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/simple_stats.cc
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/timing.cc

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_tx.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_rx.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_rx_reorder.v

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/router_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_trace.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/remote_load_trace.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/instr_trace.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_non_blocking_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/infinite_mem_profiler.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_vanilla_core_pc_cov.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_tag_master.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_io_complex.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_spmd_loader.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_monitor.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_wormhole_test_mem.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_vcache_wh_to_cache_dma.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_testbench.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/spmd_testbench.v


VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_crossbar_control_basic_o_by_i.v
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_router_crossbar_o_by_i.v

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_top_crossbar.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_crossbar.v
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_link_to_crossbar.v
