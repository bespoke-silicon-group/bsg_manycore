find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

MACHINES = 1x1 2x2 4x4

SIMV = $(addsuffix /simv, $(MACHINES))
SIMV_DAIDIR = $(addsuffix .daidir, $(SIMV))

VCS_INCDIR := +incdir+$(BASEJUMP_STL_DIR)/bsg_misc
VCS_INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_cache
VCS_INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_noc
VCS_INCDIR += +incdir+$(BSG_MANYCORE_DIR)/v
VCS_INCDIR += +incdir+$(BSG_MANYCORE_DIR)/v/vanilla_bean

.PHONY: all clean
	
all: $(SIMV)
	
%/simv:
	$(eval include $*/Makefile.machine.include)
	$(eval VCS_DEFINE := +define+BSG_GLOBAL_X=${BSG_GLOBAL_X})
	$(eval VCS_DEFINE += +define+BSG_GLOBAL_Y=${BSG_GLOBAL_Y})
	$(eval VCS_DEFINE += +define+BSG_VCACHE_SET=${BSG_VCACHE_SET})
	$(eval VCS_DEFINE += +define+BSG_VCACHE_WAY=${BSG_VCACHE_WAY})
	$(eval VCS_DEFINE += +define+BSG_VCACHE_BLOCK_SIZE=${BSG_VCACHE_BLOCK_SIZE})
	$(eval VCS_DEFINE += +define+BSG_DRAM_SIZE=${BSG_DRAM_SIZE})
	vcs +v2k -sverilog -full64 -debug_pp -o $*/simv \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS \
		-timescale=1ps/1ps +vcs+vcdpluson \
		-f sv.include $(VCS_INCDIR) $(VCS_DEFINE)

clean:
	rm -rf csrc $(SIMV_DAIDIR)
	rm -f $(SIMV)
