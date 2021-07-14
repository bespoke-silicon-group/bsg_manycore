
bsg_tiles_X = 2
bsg_tiles_Y = 1

include ../software/spmd/Makefile.include
include ../machines/arch_filelist.mk
include ./Makefile.dc

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
# By convention, basejump_stl is in the same directory as $(BSG_MANYCORE_DIR)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
BSG_SV2V_DIR := $(abspath $(BSG_MANYCORE_DIR)/../bsg_sv2v)
CURR_DIR := $(shell pwd)

all: dc

clean:
	@rm -rf *.log *.mr *.svf  *.pvl	 *.syn *.pvk *.tcl flist.vcs
dc:
	$(DC)

VPARAMS += num_tiles_x_p=16
VPARAMS += num_tiles_y_p=8
VPARAMS += pod_x_cord_width_p=3
VPARAMS += pod_y_cord_width_p=4
VPARAMS += x_cord_width_p=7
VPARAMS += y_cord_width_p=7
VPARAMS += addr_width_p=28
VPARAMS += data_width_p=32
VPARAMS += ruche_factor_X_p=3

VPARAMS += num_subarray_x_p=1
VPARAMS += num_subarray_y_p=1

VPARAMS += dmem_size_p=1024
VPARAMS += icache_entries_p=1024
VPARAMS += icache_tag_width_p=12

VPARAMS += num_vcache_rows_p=1
VPARAMS += vcache_addr_width_p=29
VPARAMS += vcache_data_width_p=32
VPARAMS += vcache_ways_p=4
VPARAMS += vcache_sets_p=64
VPARAMS += vcache_block_size_in_words_p=8
VPARAMS += vcache_size_p=2048
VPARAMS += vcache_dma_data_width_p=32

VPARAMS += wh_ruche_factor_p=2
VPARAMS += wh_cid_width_p=1
VPARAMS += wh_flit_width_p=32
VPARAMS += wh_cord_width_p=7
VPARAMS += wh_len_width_p=4

VPARAMS += num_pods_y_p=1
VPARAMS += num_pods_x_p=1

TOPMODULE = bsg_manycore_pod_ruche_array

sv2v: results/$(TOPMODULE).v.sv2v
results/$(TOPMODULE).v.sv2v: flist.vcs
	$(MAKE) -C $(BSG_SV2V_DIR) DESIGN_FILELIST=$(abspath $<) DESIGN_NAME=bsg_manycore_pod_ruche_array OUTPUT_DIR=$(@D)

flist.vcs:
	@echo -en "$(subst  ,,$(addsuffix \n, $(addprefix -pvalue+,$(VPARAMS))))  " >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(addprefix +incdir+,$(VINCLUDES))))" >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(VHEADERS)))                       " >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(VSOURCES)))                       " >> $@
	sed -i "s/^ *//" $@
