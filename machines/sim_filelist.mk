# This file contains a list of non-synthesizable files used in manycore
# simulation. These augment the sythesizable files in core.include.
VINCLUDES += $(BSG_MANYCORE_DIR)/testbenches/common/v

VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_mem_cfg_pkg.sv
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_network_cfg_pkg.sv
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_profile_pkg.sv
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_exe_bubble_classifier_pkg.sv
VHEADERS += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_scoreboard_tracker_pkg.sv
VHEADERS += $(BASEJUMP_STL_DIR)/bsg_test/bsg_dramsim3_pkg.sv

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_axi_mem.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_mem_infinite.sv

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_clock_gen.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_reset_gen.sv

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_cycle_counter.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_serial_in_parallel_out_full.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_round_robin_1_to_n.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_dataflow/bsg_one_fifo.sv


VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_trace_replay.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_tag/bsg_tag_trace_replay.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_tag/bsg_tag_master.sv


VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1r1w_sync_mask_write_byte_dma.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1r1w_sync_dma.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma.sv
CSOURCES += $(BASEJUMP_STL_DIR)/bsg_mem/bsg_mem_dma.cpp

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3_map.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_dramsim3_unmap.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_test/bsg_dramsim3.cpp
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/bankstate.cc
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
CSOURCES += $(BASEJUMP_STL_DIR)/imports/DRAMSim3/src/blood_graph.cc

VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_tx.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_rx.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_cache_to_test_dram_rx_reorder.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_cache/bsg_wormhole_to_cache_dma_fanout.sv

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/router_profiler.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_trace.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/remote_load_trace.sv
CSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/remote_load_profiler.cpp
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/instr_trace.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_profiler.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_exe_bubble_classifier.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_scoreboard_tracker.sv
CSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_profiler.cpp
CSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_pc_histogram.cpp
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_profiler.sv
CSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_profiler.cpp
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_non_blocking_profiler.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_pc_histogram.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/infinite_mem_profiler.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_tag_master.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_io_complex.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_spmd_loader.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_monitor.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_wormhole_test_mem.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_testbench.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_dma_to_dram_channel_map.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/spmd_testbench.sv


VSOURCES += $(BASEJUMP_STL_DIR)/bsg_misc/bsg_crossbar_control_basic_o_by_i.sv
VSOURCES += $(BASEJUMP_STL_DIR)/bsg_noc/bsg_router_crossbar_o_by_i.sv

VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_top_crossbar.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_crossbar.sv
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_link_to_crossbar.sv

ifeq ($(BSG_PLATFORM),vcs)
VSOURCES += $(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_manycore_vanilla_core_pc_cov.sv
endif

