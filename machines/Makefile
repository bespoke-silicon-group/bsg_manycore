.DEFAULT_GOAL = all

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
BSG_MANYCORE_ISA_DIR := $(abspath $(BSG_MANYCORE_DIR)/../bsg_manycore_ISA)

ifeq ($(wildcard $(BASEJUMP_STL_DIR)/imports/DRAMSim3/Makefile),)
$(error DRAMSim3 has not been submoduled in basejump_stl, see top-level README.md)
endif

.PHONY: all clean

include platform.mk

DEFAULT_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE))
DEFAULT_DEBUG_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-debug)
DEFAULT_PROFILE_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-profile)

# Default Machine ISA is Vanilla. This can be modified to any of the supported ISA in the repository bsg_manycore_ISA
# Note that you would have to sync the above repository as well to use another ISA
BSG_MACHINE_ISA ?= VANILLA

# set_vcs_machine_variables includes the Makefile.machine.include file and sets the
all: $(DEFAULT_TARGETS) $(DEFAULT_DEBUG_TARGETS) $(DEFAULT_PROFILE_TARGETS)

# Include source lists
# We include different source lists for different ISAs
ifeq ($(BSG_MANYCORE_ISA_DIR),VANILLA)
include $(BSG_MANYCORE_DIR)/machines/arch_filelist.mk
else ifeq ($(BSG_MANYCORE_ISA_DIR),RISCV)
include $(BSG_MANYCORE_ISA_DIR)/RISCV/arch_filelist.mk
endif

include sim_filelist.mk

include Makefile.vcs
include Makefile.verilator
include Makefile.surelog
include Makefile.xcelium

clean:
	rm -rf */csrc*
	rm -rf */xcelium.d*
	rm -rf */*.log */*.daidir */simx */simx-debug */simx-profile */simx-coverage
	rm -rf */*.log */*.daidir */simv */simv-debug */simv-profile */simv-coverage
	rm -rf */*.log */*.daidir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf */obj_dir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf stack.info.*
	rm -f */vc_hdrs.h
	rm -f */*.tr */bsg_tag_boot_rom.v
	rm -rf slpp_unit/


