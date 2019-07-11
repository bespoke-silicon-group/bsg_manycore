find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

# Sets "VCS" variable
include $(BSG_MANYCORE_DIR)/../bsg_cadenv/cadenv.mk

MACHINES = 9x15

SIMV = $(addsuffix /simv, $(MACHINES))
SIMV_DEBUG = $(addsuffix /simv-debug, $(MACHINES))
SIMV_DAIDIR = $(addsuffix .daidir, $(SIMV) $(SIMV_DEBUG))

VCS_INCDIR := +incdir+$(BASEJUMP_STL_DIR)/bsg_misc
VCS_INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_cache
VCS_INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_noc
VCS_INCDIR += +incdir+$(BSG_MANYCORE_DIR)/v
VCS_INCDIR += +incdir+$(BSG_MANYCORE_DIR)/v/vanilla_bean

.PHONY: all clean
	
all: $(SIMV)
	
%/simv:
	$(eval include $*/Makefile.machine.include)
	$(eval VCS_DEFINE := +define+BSG_MACHINE_GLOBAL_X=${BSG_MACHINE_GLOBAL_X})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_GLOBAL_Y=${BSG_MACHINE_GLOBAL_Y})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_VCACHE_SET=${BSG_MACHINE_VCACHE_SET})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_VCACHE_WAY=${BSG_MACHINE_VCACHE_WAY})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS=${BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_DRAM_SIZE_WORDS=${BSG_MACHINE_DRAM_SIZE_WORDS})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_DRAM_INCLUDED=${BSG_MACHINE_DRAM_INCLUDED})
	$(eval VCS_DEFINE += +define+BSG_MACHINE_MAX_EPA_WIDTH=${BSG_MACHINE_MAX_EPA_WIDTH})
	$(VCS) +v2k -sverilog -full64 -o $*/simv \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS \
		-timescale=1ps/1ps \
		-f sv.include $(VCS_INCDIR) $(VCS_DEFINE) | tee -i $*/build.log
	$(VCS) +v2k -sverilog -full64 -debug_pp -o $*/simv-debug \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS \
		-timescale=1ps/1ps +vcs+vcdpluson \
		-f sv.include $(VCS_INCDIR) $(VCS_DEFINE) | tee -i $*/build-debug.log

clean:
	rm -rf csrc $(SIMV_DAIDIR)
	rm -f $(SIMV) $(SIMV_DEBUG)
