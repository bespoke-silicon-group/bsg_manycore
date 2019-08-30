.DEFAULT_GOAL = all

export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
export BASEJUMP_STL_DIR := $(BSG_MANYCORE_DIR)/../basejump_stl

# Sets "VCS" variable
include $(BSG_MANYCORE_DIR)/../bsg_cadenv/cadenv.mk

# Include source lists
include Makefile.include

MACHINES = 9x15 4x4

.PHONY: all clean

all: $(foreach machine, $(MACHINES), $(machine)/stamp)

%/stamp: $(VCS_SOURCES) $(VCS_INCLUDES)
	$(eval include $*/Makefile.machine.include)
	$(eval VCS_MACRO_DEFS := +define+BSG_MACHINE_GLOBAL_X=${BSG_MACHINE_GLOBAL_X})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_GLOBAL_Y=${BSG_MACHINE_GLOBAL_Y})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_VCACHE_SET=${BSG_MACHINE_VCACHE_SET})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_VCACHE_WAY=${BSG_MACHINE_VCACHE_WAY})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS=${BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_DRAM_SIZE_WORDS=${BSG_MACHINE_DRAM_SIZE_WORDS})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_DRAM_INCLUDED=${BSG_MACHINE_DRAM_INCLUDED})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_MAX_EPA_WIDTH=${BSG_MACHINE_MAX_EPA_WIDTH})
	$(eval VCS_MACRO_DEFS += +define+BSG_MACHINE_MEM_CFG=${BSG_MACHINE_MEM_CFG})
	$(VCS) +v2k -sverilog -full64 -o $*/simv \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS \
		-timescale=1ps/1ps \
		$(VCS_INCDIRS) $(VCS_DEFINES) $(VCS_SOURCES) $(VCS_MACRO_DEFS) | tee -i $*/build.log
	$(VCS) +v2k -sverilog -full64 -debug_pp -o $*/simv-debug \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS \
		-timescale=1ps/1ps +vcs+vcdpluson \
		$(VCS_INCDIRS) $(VCS_DEFINES) $(VCS_SOURCES) $(VCS_MACRO_DEFS) | tee -i $*/build-debug.log
	touch $@

clean:
	rm -rf csrc
	@for machine_dir in $(MACHINES); do \
		rm -rf $$machine_dir/stamp $$machine_dir/*.log ; \
		rm -rf $$machine_dir/simv* ; \
	done;
