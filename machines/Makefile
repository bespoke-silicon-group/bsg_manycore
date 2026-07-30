.DEFAULT_GOAL = all

.PHONY: all clean

include paths.mk
include platform.mk

DEFAULT_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE))
DEFAULT_DEBUG_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-debug)
DEFAULT_PROFILE_TARGETS = $(foreach machine, $(DEFAULT_MACHINES),$(machine)/$(BSG_SIM_BASE)-profile)

# set_vcs_machine_variables includes the Makefile.machine.include file and sets the
all: $(DEFAULT_TARGETS) $(DEFAULT_DEBUG_TARGETS) $(DEFAULT_PROFILE_TARGETS)
machine: $(BSG_MACHINE)/$(BSG_SIM_BASE)

# Include source lists
include arch_filelist.mk
include sim_filelist.mk

include Makefile.vcs
include Makefile.verilator
include Makefile.surelog
include Makefile.xcelium

clean:
	rm -rf */csrc*
	rm -rf */xcelium.d*
	rm -rf */*.log */*.daidir */simx */simx-debug */simx-profile */simx-coverage
	rm -rf */*.log */*.daidir */simv */simv-debug */simv-profile */simv-coverage
	rm -rf */*.log */*.daidir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf */obj_dir */simsc */simsc-debug */simsc-profile */simsc-coverage
	rm -rf stack.info.*
	rm -f */vc_hdrs.h
	rm -f */*.tr */bsg_tag_boot_rom.v
	rm -rf slpp_unit/


