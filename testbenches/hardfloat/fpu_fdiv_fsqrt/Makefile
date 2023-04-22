export BSG_MANYCORE_DIR = $(shell git rev-parse --show-toplevel)
export HARDFLOAT_DIR    = $(BSG_MANYCORE_DIR)/imports/HardFloat
export BSG_CADENV_DIR   = $(abspath $(BSG_MANYCORE_DIR)/../bsg_cadenv)
export BASEJUMP_STL_DIR = $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
include $(BSG_CADENV_DIR)/cadenv.mk

VCS_INCDIR += +incdir+$(HARDFLOAT_DIR)/source
VCS_INCDIR += +incdir+$(HARDFLOAT_DIR)/source/RISCV
VCS_INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_misc

run: 
	vcs +v2k -R -sverilog -full64 -f sv.include -l vcs.log \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson $(VCS_INCDIR) -top test_fpu_fdiv_fsqrt


dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf csrc DVEfiles output_32.txt simv simv.daidir vcs.log vcdplus.vpd ucli.key
