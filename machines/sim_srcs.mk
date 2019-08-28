# This file contains a list of non-synthesizable files used in manycore
# simulation. These augment the sythesizable files in core.include.

SIM_SRCS =$(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_mem_cfg_pkg.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/memory_system.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_cache_wrapper_axi.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_axi_mem.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_nonsynth_mem_infinite.v

SIM_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_mask_write_byte_assoc.v
SIM_SRCS+=$(BASEJUMP_STL_DIR)/bsg_mem/bsg_nonsynth_mem_1rw_sync_assoc.v

SIM_SRCS+=$(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_clock_gen.v
SIM_SRCS+=$(BASEJUMP_STL_DIR)/bsg_test/bsg_nonsynth_reset_gen.v

SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/instr_trace.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_trace.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/bsg_manycore_link_to_cache_tracer.v

SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/vanilla_core_profiler.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/vcache_profiler.v
SIM_SRCS+=$(BSG_MANYCORE_DIR)/testbenches/common/v/infinite_mem_profiler.v
