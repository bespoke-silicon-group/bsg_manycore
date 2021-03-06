.DEFAULT_GOAL = all

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)

# Sets "VCS" variable
include $(BSG_MANYCORE_DIR)/../bsg_cadenv/cadenv.mk

# Include source lists
include arch_filelist.mk
include sim_filelist.mk

VCS_INCLUDES += $(foreach inc,$(VINCLUDES),+incdir+"$(inc)")
VCS_DEFINES  += $(foreach def,$(VDEFINES),+define+"$(def)")
VCS_SOURCES  += $(VHEADERS) $(VSOURCES) 
VCS_FLAGS    += +v2k -sverilog -full64 -timescale=1ps/1ps \
    +lint=all,noSVA-UA,noSVA-NSVU,noVCDE,noNS -top spmd_testbench
VCS_FLAGS    += -licqueue
VCS_FLAGS    += -reportstats
VCS_FLAGS    += -assert svaext  # needed for "assert final"
#VCS_FLAGS    += +vcs+loopreport

VCS_CFLAGS   =  -cpp g++
VCS_CFLAGS   += -CFLAGS "-std=c++11 -g -Wall"
VCS_CFLAGS   += -CFLAGS "-O2"
VCS_CFLAGS   += -CFLAGS "-fPIC"
VCS_CFLAGS 	 += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/src"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/ext/headers"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/imports/DRAMSim3/ext/fmt/include"
VCS_CFLAGS   += -CFLAGS "-I$(BASEJUMP_STL_DIR)/bsg_test"
VCS_CFLAGS   += -CFLAGS "-DFMT_HEADER_ONLY=1"
VCS_CFLAGS   += -CFLAGS "-DBASEJUMP_STL_DIR=$(BASEJUMP_STL_DIR)"

DEFAULT_MACHINES = pod_1x1 pod_1x1_hbm2 pod_4x4

.PHONY: all clean

DEFAULT_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simv)
DEFAULT_DEBUG_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simv-debug)
DEFAULT_PROFILE_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/simv-profile)

all: $(DEFAULT_TARGETS) $(DEFAULT_DEBUG_TARGETS) $(DEFAULT_PROFILE_TARGETS)

# set_machine_variables includes the Makefile.machine.include file and sets the
# VCS_DEFINES that define the architecture for a machine. This should be called
# from inside of the rule that builds the machine-specific executable for a
# machine so that the *correct* Makfile.machine.include can be included
define set_machine_variables
	$(eval include $1)
	$(eval VCS_DEFINES := +define+BSG_MACHINE_PODS_X=${BSG_MACHINE_PODS_X})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_PODS_Y=${BSG_MACHINE_PODS_Y})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_ORIGIN_X_CORD=${BSG_MACHINE_ORIGIN_X_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_ORIGIN_Y_CORD=${BSG_MACHINE_ORIGIN_Y_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_GLOBAL_X=${BSG_MACHINE_GLOBAL_X})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_GLOBAL_Y=${BSG_MACHINE_GLOBAL_Y})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HOST_X_CORD=${BSG_MACHINE_HOST_X_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HOST_Y_CORD=${BSG_MACHINE_HOST_Y_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_ORIGIN_Y_CORD=${BSG_MACHINE_ORIGIN_Y_CORD})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_SET=${BSG_MACHINE_VCACHE_SET})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_WAY=${BSG_MACHINE_VCACHE_WAY})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS=${BSG_MACHINE_VCACHE_BLOCK_SIZE_WORDS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_DMA_DATA_WIDTH=${BSG_MACHINE_VCACHE_DMA_DATA_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_VCACHE_MISS_FIFO_ELS=${BSG_MACHINE_VCACHE_MISS_FIFO_ELS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAM_SIZE_WORDS=${BSG_MACHINE_DRAM_SIZE_WORDS})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAM_INCLUDED=${BSG_MACHINE_DRAM_INCLUDED})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_MAX_EPA_WIDTH=${BSG_MACHINE_MAX_EPA_WIDTH})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_MEM_CFG=${BSG_MACHINE_MEM_CFG})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_BRANCH_TRACE_EN=${BSG_MACHINE_BRANCH_TRACE_EN})
	$(eval VCS_DEFINES += +define+BSG_MACHINE_HETERO_TYPE_VEC="${BSG_MACHINE_HETERO_TYPE_VEC}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_NETWORK_CFG="${BSG_MACHINE_NETWORK_CFG}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_RUCHE_FACTOR_X="${BSG_MACHINE_RUCHE_FACTOR_X}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_SUBARRAY_X="${BSG_MACHINE_SUBARRAY_X}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_SUBARRAY_Y="${BSG_MACHINE_SUBARRAY_Y}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_NUM_VCACHE_ROWS="${BSG_MACHINE_NUM_VCACHE_ROWS}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_NUM_VCACHES_PER_CHANNEL="${BSG_MACHINE_NUM_VCACHES_PER_CHANNEL}")
	$(eval VCS_DEFINES += +define+BSG_MACHINE_DRAMSIM3_PKG="${BSG_MACHINE_DRAMSIM3_PKG}")
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
# build simv
# without debug option for faster simulation.
%/simv : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	$(VCS) $(VCS_FLAGS) $(VCS_CFLAGS) -o $@ \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v \
		-l $*/build.log -Mdir=$*/csrc

# build simv-debug
# with debug option for waveform generation.
%/simv-debug : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	$(eval VCS_FLAGS += -debug_pp +vcs+vcdpluson) # Debug adds these two variables to generate waveforms
	$(VCS) $(VCS_FLAGS) $(VCS_CFLAGS) -o $@ \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v \
		-l $*/build-debug.log -Mdir=$*/csrc-debug

# building simv-profile
# with trace-based profiler for bloodgraphs etc
%/simv-profile : %/Makefile.machine.include $(VSOURCES) $(CSOURCES) $(VINCLUDES) $(VHEADERS) 
	$(call set_machine_variables,$<)
	python $(POD_TRACE_GEN_PY) $(BSG_MACHINE_PODS_X) $(BSG_MACHINE_PODS_Y) > $*/pod_trace.tr
	python $(ASCII_TO_ROM_PY) $*/pod_trace.tr bsg_tag_boot_rom > $*/bsg_tag_boot_rom.v
	$(eval VCS_FLAGS += +define+BSG_ENABLE_PROFILING) # Debug adds these two variables to generate waveforms
	$(eval VCS_CFLAGS   += -CFLAGS "-DBLOOD_GRAPH")
	$(VCS) $(VCS_FLAGS) $(VCS_CFLAGS) -o $@ \
		$(VCS_INCLUDES) $(VCS_DEFINES) $(CSOURCES) $(VCS_SOURCES) $*/bsg_tag_boot_rom.v \
		-l $*/build-profile.log -Mdir=$*/csrc-profile


clean:
	rm -rf */csrc*
	rm -rf */*.log */*.daidir */simv */simv-debug */simv-profile
	rm -rf stack.info.*
	rm -f */vc_hdrs.h
	rm -f */*.tr */bsg_tag_boot_rom.v
