BSG_MANYCORE_DIR := $(abspath ../..)
BASEJUMP_STL_DIR ?= $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
include $(BSG_MANYCORE_DIR)/machines/arch_filelist.mk

XRUN ?= xrun
RUCHE_FACTOR_Y ?= 3
BUILD_DIR ?= $(CURDIR)/build
TESTBENCH := $(CURDIR)/test_bsg_manycore_tile_vcache_ruche.sv

.PHONY: run
run:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && $(XRUN) -64bit -sv -timescale 1ps/1ps \
		-top test_bsg_manycore_tile_vcache_ruche \
		-defparam test_bsg_manycore_tile_vcache_ruche.ruche_factor_Y_p=$(RUCHE_FACTOR_Y) \
		$(addprefix +incdir+,$(VINCLUDES)) $(VHEADERS) $(VSOURCES) $(TESTBENCH)
