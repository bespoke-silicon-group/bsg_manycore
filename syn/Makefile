
include ../software/spmd/Makefile.include
include ../machines/arch_filelist.mk

BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
BASEJUMP_STL_DIR := $(abspath $(BSG_MANYCORE_DIR)/../basejump_stl)
BSG_SV2V_DIR     := $(abspath $(BSG_MANYCORE_DIR)/../bsg_sv2v)

all: sv2v

clean:
	@rm -rf *.log *.mr *.svf  *.pvl	 *.syn *.pvk *.tcl results/

# Supported sv2v targets
#DESIGN_NAME ?= bsg_manycore_tile_compute_mesh
DESIGN_NAME ?= bsg_manycore_tile_compute_ruche
#DESIGN_NAME ?= bsg_manycore_tile_vcache
# Warning: bsg_manycore_pod_ruche takes upwards of 6 hours on a beefy machine
#   to run through sv2v. Hierarchical sv2v (not currently supported) is recommended
#DESIGN_NAME ?= bsg_manycore_pod_ruche

# Tile parameters
ifneq ($(DESIGN_NAME),bsg_manycore_tile_vcache)
VPARAMS += num_tiles_x_p=16
VPARAMS += pod_x_cord_width_p=3
VPARAMS += pod_y_cord_width_p=4
VPARAMS += dmem_size_p=1024
VPARAMS += icache_entries_p=1024
VPARAMS += icache_tag_width_p=12
VPARAMS += num_vcache_rows_p=1
endif

VPARAMS += num_tiles_y_p=8
VPARAMS += x_cord_width_p=7
VPARAMS += y_cord_width_p=7
VPARAMS += addr_width_p=28
VPARAMS += data_width_p=32

ifneq ($(DESIGN_NAME),bsg_manycore_tile_compute_ruche)
ifneq ($(DESIGN_NAME),bsg_manycore_tile_compute_mesh)
VPARAMS += vcache_addr_width_p=29
VPARAMS += vcache_data_width_p=32
VPARAMS += vcache_ways_p=4
VPARAMS += vcache_sets_p=64
VPARAMS += vcache_block_size_in_words_p=8
VPARAMS += vcache_dma_data_width_p=32

VPARAMS += wh_ruche_factor_p=2
VPARAMS += wh_cid_width_p=1
VPARAMS += wh_flit_width_p=32
VPARAMS += wh_cord_width_p=7
VPARAMS += wh_len_width_p=4
endif
endif

ifeq ($(DESIGN_NAME),bsg_manycore_pod_ruche)
VPARAMS += vcache_size_p=2048
VPARAMS += ruche_factor_X_p=3

VPARAMS += num_subarray_x_p=1
VPARAMS += num_subarray_y_p=1

endif

sv2v: results/$(DESIGN_NAME).v.sv2v
results/$(DESIGN_NAME).v.sv2v: results/flist.vcs
	$(MAKE) -C $(BSG_SV2V_DIR) DESIGN_NAME=$(DESIGN_NAME) DESIGN_FILELIST=$(abspath $<) OUTPUT_DIR=$(abspath $(@D))

results/flist.vcs:
	mkdir -p $(@D)
	@echo -en "$(subst  ,,$(addsuffix \n, $(addprefix -pvalue+,$(VPARAMS))))  " >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(addprefix +incdir+,$(VINCLUDES))))" >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(VHEADERS)))                       " >> $@
	@echo -en "$(subst  ,,$(addsuffix \n, $(VSOURCES)))                       " >> $@
	@echo "$(BSG_MANYCORE_DIR)/v/bsg_manycore_tile_compute_mesh.v"       >> $@
	@# Adding hardened sram wrappers
	@echo "+incdir+$(BASEJUMP_STL_DIR)/hard/pickle/bsg_mem"              >> $@
	@# Remove old memories
	@sed -i "/bsg_mem_1rw_sync.v/d"                                         $@
	@sed -i "/bsg_mem_1rw_sync_mask_write_byte.v/d"                         $@
	@sed -i "/bsg_mem_1rw_sync_mask_write_bit.v/d"                          $@
	@# Swap new hardened wrappers
	@echo "$(BSG_MANYCORE_DIR)/syn/v/bsg_mem_1rw_sync.v"                 >> $@
	@echo "$(BSG_MANYCORE_DIR)/syn/v/bsg_mem_1rw_sync_mask_write_byte.v" >> $@
	@echo "$(BSG_MANYCORE_DIR)/syn/v/bsg_mem_1rw_sync_mask_write_bit.v"  >> $@
	@# Trim whitespace from beginning of lines
	@sed -i "s/^ *//"                                                       $@

