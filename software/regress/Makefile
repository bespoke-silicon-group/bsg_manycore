# Multi-corner regression
#

# Process corner format: <corner>_<rc_corner>[_ss]
CORNERS := ffpg0p88vm40c_SigRCmax ffpg0p88vm40c_SigRCmin ffpg0p88v125c_SigRCmax ffpg0p88v125c_SigRCmin 
RUNS := $(foreach corner, $(CORNERS), $(corner)-0) $(foreach corner, $(CORNERS), $(corner)-1)
REGRESS_LIST := hello quicktouch

BSG_MANYCORE_URL := git@github.com:bespoke-silicon-group/bsg_manycore.git
BSG_MANYCORE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.paths

# Intended for machine paths pointing to bsg_designs
BSG_DESIGN_BUILD_DIR := $(subst /out,,$(BSG_MACHINE_PATH))


nothing:


checkout:
	-rm -rf tmp.bsg_manycore/
	git clone --recursive $(BSG_MANYCORE_URL) tmp.bsg_manycore
	cd tmp.bsg_manycore/ && git checkout $(BSG_MANYCORE_BRANCH)
	ln -s $(BSG_MANYCORE_DIR)/software/riscv-tools/riscv-install/ tmp.bsg_manycore/software/riscv-tools/riscv-install
	for run in $(RUNS); do \
		cp -R tmp.bsg_manycore/ bsg_manycore_$$run/; \
	done;
	rm -rf tmp.bsg_manycore/
	ln -s $(BSG_MANYCORE_DIR)/../bsg_cadenv bsg_cadenv

bleach-checkout:
	-rm -rf tmp.bsg_manycore/
	-rm -rf $(foreach run,$(RUNS),bsg_manycore_$(run))
	-rm bsg_cadenv


build: $(foreach corner,$(CORNERS),build-$(corner))

build-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
build-%: corner=$(word 1, $(subst _, ,$*))
build-%: rc_corner=$(word 2,$(subst _, ,$*))
build-%: corner_ss=$(word 3,$(subst _, ,$*))
build-%:
	mkdir -p $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) corner=$(corner) rc_corner=$(rc_corner) CORNER_SS=$(corner_ss) BSG_OUT_DIR=$(machine_dir) build

bleach-build:
	-rm -rf $(foreach corner,$(CORNERS),machine-$(corner))
	-rm vc_hdrs.h


run: $(foreach run,$(RUNS),run-$(run))

run-%: run_dir=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*/software/spmd
run-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$(word 1, $(subst -, ,$*))
run-%:
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) recurse-clean

	# Below two commands are for fetching hacked nbf. Can be removed.
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) $(foreach test,$(REGRESS_LIST),recurse-iterate@main.nbf@$(test))
	for test in $(REGRESS_LIST); do \
		cp $(BSG_MANYCORE_DIR)/software/nbf/9x15_nodram/$$test.nbf $(run_dir)/$$test/main.nbf 2>/dev/null; \
	done;

	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) BSG_MACHINE_DRAM_INCLUDED=$(word 2, $(subst -, ,$*)) $(foreach test,$(REGRESS_LIST),recurse-iterate@all@$(test))


clean_runs: $(foreach run,$(RUNS),clean-$(run))

clean-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$(word 1, $(subst -, ,$*))
clean-%: run_dir=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*/software/spmd
clean-%:
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) recurse-clean


bleach_all: bleach-checkout bleach-build
