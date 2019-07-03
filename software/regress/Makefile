# Multi-corner regression
#
# Process corner format: <corner>_<rc_corner>[_ss]
CORNERS := c1_rc1 c2_rc2_ss
REGRESS_LIST := hello# bsg_riscv_tests quicktouch bsg_remote_load

BSG_MANYCORE_URL := git@github.com:bespoke-silicon-group/bsg_manycore.git
BSG_MANYCORE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.paths

# Intended for machine paths pointing to bsg_designs
BSG_DESIGN_BUILD_DIR := $(subst /out,,$(BSG_MACHINE_PATH))


nothing:


checkout: $(foreach corner,$(CORNERS),checkout-$(corner))
	ln -s $(BSG_MANYCORE_DIR)/../bsg_cadenv bsg_cadenv

checkout-%: run_repo=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*
checkout-%:
	-rm -rf $(run_repo)
	git clone --recursive $(BSG_MANYCORE_URL) $(run_repo)
	cd $(run_repo)/ && git checkout $(BSG_MANYCORE_BRANCH)
	ln -s $(BSG_MANYCORE_DIR)/software/riscv-tools/riscv-install/ $(run_repo)/software/riscv-tools/riscv-install

bleach-checkout:
	-rm -rf $(foreach corner,$(CORNERS),bsg_manycore_$(corner))
	-rm bsg_cadenv


build: $(foreach corner,$(CORNERS),build-$(corner))

build-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
build-%: corner=$(word 1, $(subst _, ,$*))
build-%: rc_corner=$(word 2,$(subst _, ,$*))
build-%: corner_ss=$(word 3,$(subst _, ,$*))
build-%:
	mkdir -p $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) clean
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) corner=$(corner) rc_corner=$(rc_corner) CORNER_SS=$(corner_ss) build
	cp -R $(BSG_DESIGN_BUILD_DIR)/out/* $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) clean

bleach-build:
	-rm -rf $(foreach corner,$(CORNERS),machine-$(corner))


run: $(foreach corner,$(CORNERS),run-$(corner))

run-%: run_dir=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*/software/spmd
run-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
run-%:
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) recurse-clean
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) $(foreach test,$(REGRESS_LIST),recurse-iterate@all@$(test))


clean_runs: $(foreach corner,$(CORNERS),clean-$(corner))

clean-%: run_dir=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*/software/spmd
clean-%:
	$(MAKE) -C $(run_dir) recurse-clean


bleach_all: bleach-checkout bleach-build
