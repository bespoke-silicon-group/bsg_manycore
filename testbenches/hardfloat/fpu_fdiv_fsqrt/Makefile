export BSG_MANYCORE_DIR = $(shell git rev-parse --show-toplevel)
export HARDFLOAT_DIR    = $(BSG_MANYCORE_DIR)/imports/HardFloat
export BSG_CADENV_DIR   = $(abspath $(BSG_MANYCORE_DIR)/../bsg_cadenv)
include $(BSG_CADENV_DIR)/cadenv.mk

VCS_INCDIR += +incdir+$(HARDFLOAT_DIR)/source
VCS_INCDIR += +incdir+$(HARDFLOAT_DIR)/source/RISCV

run: 
	vcs +v2k -R -sverilog -full64 -f sv.include -l vcs.log \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson $(VCS_INCDIR)


dve:
	dve -full64 -vpd vcdplus.vpd &
