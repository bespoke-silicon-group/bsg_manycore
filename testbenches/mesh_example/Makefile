###########################################
# DEFINE THE PATHS
BSG_IP_CORES_DIR=$(abspath  ../../../bsg_ip_cores)
BSG_MANYCORE_DIR=$(abspath  ../../../bsg_manycore)

CAD_DIR=$(abspath ../../../cad)

###########################################
# SETUP THE TOOL PATHS
# include $(CAD_DIR)/common/mk/cadenv.mk

#############################################
# SETUP THE INCLUDE PATH and SEARCH PATH
INC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_noc
INC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_misc
INC_DIRS	+= $(BSG_MANYCORE_DIR)/v/

SRC_DIRS	+= $(BSG_MANYCORE_DIR)/v/
SRC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_misc
SRC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_noc
SRC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_dataflow
SRC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_test
SRC_DIRS	+= $(BSG_IP_CORES_DIR)/bsg_mem
SRC_DIRS	+= ./

PKG_FILES	+= $(BSG_IP_CORES_DIR)/bsg_misc/bsg_defines.v
PKG_FILES	+= $(BSG_IP_CORES_DIR)/bsg_noc/bsg_noc_pkg.v

###########################################
# DEFINE THE VCS OPTIONS
VCS_OP	    =-full64 -sverilog
# compile and run 
VCS_OP     += -R
# search *.v files for module
VCS_OP     += +libext+.v
#enable waveform dump
VCS_OP     +=  +vcs+vcdpluson -debug_pp
#setup the timescale
VCS_OP     += -timescale=1ns/1ps

run: 
	$(VCS) $(VCS_OP) 			\
	$(addprefix +incdir+, $(INC_DIRS) )	\
	$(addprefix -y , $(SRC_DIRS)     )	\
	$(PKG_FILES)				\
	test_bench.v -top test_bench
dve:
	$(VCS_BIN)/dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf csrc DVEfiles *.tar.gz simv simv.daidir ucli.key vcdplus.vpd

