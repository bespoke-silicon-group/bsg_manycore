BSG_MANYCORE_DIR := $(abspath ../..)
BASEJUMP_STL_DIR ?= $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
include $(BSG_MANYCORE_DIR)/machines/arch_filelist.mk

XRUN ?= xrun
RUCHE_FACTOR_Y ?= 3
BARRIER_RUCHE_FACTOR_Y ?= $(RUCHE_FACTOR_Y)
SUBARRAY_X ?= 2
SUBARRAY_Y ?= 2
BUILD_DIR ?= $(CURDIR)/build
TOP ?= test_bsg_manycore_tile_compute_ruche_full
TESTBENCH := $(CURDIR)/$(TOP).sv

.PHONY: run
run:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && $(XRUN) -64bit -sv -timescale 1ps/1ps \
		-top $(TOP) \
		+define+BSG_TEST_RUCHE_FACTOR_Y=$(RUCHE_FACTOR_Y) \
		+define+BSG_TEST_BARRIER_RUCHE_FACTOR_Y=$(BARRIER_RUCHE_FACTOR_Y) \
		+define+BSG_TEST_SUBARRAY_X=$(SUBARRAY_X) \
		+define+BSG_TEST_SUBARRAY_Y=$(SUBARRAY_Y) \
		$(addprefix +incdir+,$(VINCLUDES)) $(VHEADERS) $(VSOURCES) $(TESTBENCH)
