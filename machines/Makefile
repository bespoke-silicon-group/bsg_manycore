.DEFAULT_GOAL = all

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)

ifeq ($(wildcard $(BASEJUMP_STL_DIR)/imports/DRAMSim3/Makefile),)
$(error DRAMSim3 has not been submoduled in basejump_stl, see top-level README.md)
endif

# Sets "VCS" variable
-include $(BSG_MANYCORE_DIR)/../bsg_cadenv/cadenv.mk

ifeq ($(VCS),)
#$(error VCS must be set; probably need VCS_HOME, SNPSLMD_LICENSE_FILE too, maybe LM_LICENSE file)
endif

# Include source lists
include arch_filelist.mk
include sim_filelist.mk

VCS_INCLUDES += $(foreach inc,$(VINCLUDES),+incdir+"$(inc)")
VCS_DEFINES  += $(foreach def,$(VDEFINES),+define+"$(def)")
VCS_SOURCES  += $(VHEADERS) $(VSOURCES) 
#VCS_FLAGS    += +v2k -sverilog -full64 -timescale=1ps/1ps \
#    +lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS
VCS_FLAGS +=--top-module spmd_testbench
#VCS_FLAGS    += -licqueue
#VCS_FLAGS    += -reportstats
#VCS_FLAGS    += -assert svaext  # needed for "assert final"
#VCS_FLAGS    += --lint-only
VCS_FLAGS     += --cc
VCS_FLAGS     += -Wno-fatal
#VCS_FLAGS    += --debug -gdbbt
VCS_FLAGS    += -O2
VCS_FLAGS    += --trace-fst
VCS_FLAGS    += --trace-structs
#VCS_FLAGS    += +vcs+loopreport 

#VCS_CFLAGS   =  -cpp g++
VCS_CFLAGS   += -CFLAGS "-std=c++11 -g -Wall"
#VCS_CFLAGS   += -CFLAGS "-O2"
VCS_CFLAGS   += -CFLAGS "-fPIC"
VCS_CFLAGS 	 += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/src"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/ext/headers"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/ext/fmt/include"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/bsg_test"
VCS_CFLAGS   += -CFLAGS "-I../../verilator/include"
VCS_CFLAGS   += -CFLAGS "-DFMT_HEADER_ONLY=1"
VCS_CFLAGS   += -CFLAGS "-DBASEJUMP_STL_DIR=$(BASEJUMP_STL_DIR)"

#DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4
DEFAULT_MACHINES = pod_1x1

.PHONY: all clean

DEFAULT_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simsc)
DEFAULT_DEBUG_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simsc-debug)
DEFAULT_PROFILE_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simsc-profile)

all: $(DEFAULT_TARGETS)
#$(DEFAULT_DEBUG_TARGETS) $(DEFAULT_PROFILE_TARGETS)

# set_machine_variables includes the Makefile.machine.include file and sets the
# VCS_DEFINES that define the architecture for a machine. This should be called
# from inside of the rule that builds the machine-specific executable for a
# machine so that the *correct* Makfile.machine.include can be included
define set_machine_variables
	$(eval include $1)
	$(eval VCS_DEFINES := +define+BSG_MACHINE_PODS_X=${BSG_MACHINE_PODS_X})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_PODS_Y=${BSG_MACHINE_PODS_Y})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_GLOBAL_X=${BSG_MACHINE_GLOBAL_X})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_GLOBAL_Y=${BSG_MACHINE_GLOBAL_Y})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_X_CORD_WIDTH=${BSG_MACHINE_X_CORD_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_Y_CORD_WIDTH=${BSG_MACHINE_Y_CORD_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_RUCHE_FACTOR_X=${BSG_MACHINE_RUCHE_FACTOR_X})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_NUM_VCACHE_ROWS="${BSG_MACHINE_NUM_VCACHE_ROWS}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_SET=${BSG_MACHINE_VCACHE_SET})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_WAY=${BSG_MACHINE_VCACHE_WAY})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS=${BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_DMA_DATA_WIDTH=${BSG_MACHINE_VCACHE_DMA_DATA_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_NUM_VCACHES_PER_CHANNEL="${BSG_MACHINE_NUM_VCACHES_PER_CHANNEL}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAM_SIZE_WORDS=${BSG_MACHINE_DRAM_SIZE_WORDS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAM_BANK_SIZE_WORDS=${BSG_MACHINE_DRAM_BANK_SIZE_WORDS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAM_INCLUDED=${BSG_MACHINE_DRAM_INCLUDED})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_MAX_EPA_WIDTH=${BSG_MACHINE_MAX_EPA_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_BRANCH_TRACE_EN=${BSG_MACHINE_BRANCH_TRACE_EN})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HETERO_TYPE_VEC="${BSG_MACHINE_HETERO_TYPE_VEC}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_ORIGIN_X_CORD=${BSG_MACHINE_ORIGIN_X_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_ORIGIN_Y_CORD=${BSG_MACHINE_ORIGIN_Y_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HOST_X_CORD=${BSG_MACHINE_HOST_X_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HOST_Y_CORD=${BSG_MACHINE_HOST_Y_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_MEM_CFG=${BSG_MACHINE_MEM_CFG})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAMSIM3_PKG="${BSG_MACHINE_DRAMSIM3_PKG}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_SUBARRAY_X="${BSG_MACHINE_SUBARRAY_X}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_SUBARRAY_Y="${BSG_MACHINE_SUBARRAY_Y}")
	# specify where the host module is instantiated for profiler trigger (print_stat).
	# relative to $root
	$(eval VCS_DEFINES += +define+HOST_MODULE_PATH=spmd_testbench) 
	# These define are required by mobile_ddr.v.
	# density     	= 2048 Mbit
	# speed grade 	= 5
	# organization 	= x16
	# allocation    = FULL_MEM
	$(eval VCS_DEFINES += +define+den2048Mb+sg5+x16+FULL_MEM)
endef

# boot tag rom gen
POD_TRACE_GEN_PY = $(BSG_MANYCORE_DIR)/testbenches/py/pod_trace_gen.py
ASCII_TO_ROM_PY = $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py 
# build simsc
# without debug option for faster simulation.
%/simsc : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS)
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	../../verilator/bin/verilator -j 32 --build --exe $(VCS_FLAGS) $(VCS_CFLAGS) -Mdir $(@D)/obj_dir -o $(@F) \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v
	ln -nsf $(@D)/obj_dir/simsc $@
		

# build simsc-debug
# with debug option for waveform generation.
%/simsc-debug : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	$(eval VCS_FLAGS += -debug_pp +vcs+vcdpluson) # Debug adds these two variables to generate waveforms
	$(VCS) $(VCS_FLAGS) $(VCS_CFLAGS) -o $@ \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v \
		-l $*/build-debug.log -Mdir=$*/csrc-debug

# building simsc-profile
# with trace-based profiler for bloodgraphs etc
%/simsc-profile : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	$(eval VCS_FLAGS += +define+BSG_ENABLE_PROFILING) # Debug adds these two variables to generate waveforms
	$(eval VCS_CFLAGS   += -CFLAGS "-DBLOOD_GRAPH")
	$(VCS) $(VCS_FLAGS) $(VCS_CFLAGS) -o $@ \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v \
		-l $*/build-profile.log -Mdir=$*/csrc-profile

# build simsc-coverage
# with coverage options for code/functional coverage
%/simsc-coverage : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(error Coverage is not currently supported for Verilator)

clean:
	rm -rf */csrc*
	rm -rf */*.log */*.daidir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf stack.info.*
	rm -f */vc_hdrs.h
	rm -f */*.tr */bsg_tag_boot_rom.v

