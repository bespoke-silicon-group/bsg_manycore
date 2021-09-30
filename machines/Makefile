.DEFAULT_GOAL = all

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)

ifeq ($(wildcard $(BASEJUMP_STL_DIR)/imports/DRAMSim3/Makefile),)
$(error DRAMSim3 has not been submoduled in basejump_stl, see top-level README.md)
endif

# Include source lists
include arch_filelist.mk
include sim_filelist.mk

TOOL ?= VCS
ifeq ($(TOOL),VCS)
  include Makefile.vcs
else ifeq ($(TOOL),VERILATOR)
  include Makefile.verilator
else
  $(error Invalid TOOL $(TOOL) selected)
endif

