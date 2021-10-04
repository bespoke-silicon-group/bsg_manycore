.DEFAULT_GOAL = all

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)

BSG_PLATFORM ?= vcs

ifeq ($(wildcard $(BASEJUMP_STL_DIR)/imports/DRAMSim3/Makefile),)
$(error DRAMSim3 has not been submoduled in basejump_stl, see top-level README.md)
endif

.PHONY: all clean

ifeq ($(BSG_PLATFORM),vcs)
DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4
BSG_SIM_BASE = simv
else ifeq ($(BSG_PLATFORM),verilator)
DEFAULT_MACHINES = pod_1x1_4X2Y
BSG_SIM_BASE = simsc
endif

DEFAULT_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE))
DEFAULT_DEBUG_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-debug)
DEFAULT_PROFILE_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-profile)

# set_vcs_machine_variables includes the Makefile.machine.include file and sets the
all: $(DEFAULT_TARGETS) $(DEFAULT_DEBUG_TARGETS) $(DEFAULT_PROFILE_TARGETS)

# Include source lists
include arch_filelist.mk
include sim_filelist.mk

include Makefile.vcs
include Makefile.verilator

clean:
	rm -rf */csrc*
	rm -rf */*.log */*.daidir */simv */simv-debug */simv-profile */simv-coverage
	rm -rf */*.log */*.daidir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf */obj_dir_* */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf stack.info.*
	rm -f */vc_hdrs.h
	rm -f */*.tr */bsg_tag_boot_rom.v


