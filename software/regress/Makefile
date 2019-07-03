# Multi-corner regression
#
# Process corner format: <corner>_<rc_corner>[_ss]
CORNERS := ???_rc??? xyz_rcxyz_ss
REGRESS_LIST := hello# bsg_riscv_tests quicktouch bsg_remote_load

BSG_MANYCORE_URL := git@github.com:bespoke-silicon-group/bsg_manycore.git
BSG_MANYCORE_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
BSG_MANYCORE_COMMIT := $(strip $(shell git log | sed -n 1p | sed s/commit//))
BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.paths

# Intended for machine paths pointing to bsg_designs
BSG_DESIGN_BUILD_DIR := $(BSG_MACHINE_PATH)/..

nothing:

build: $(foreach corner,$(CORNERS),checkout-mc-$(corner)) \
       $(foreach corner,$(CORNERS),machine-gen-$(corner))

checkout-mc-%: run_repo=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*
checkout-mc-%:
	-rm -rf $(run_repo)
	git clone $(BSG_MANYCORE_URL) $(run_repo)
	cd $(run_repo)/ && git checkout $(BSG_MANYCORE_BRANCH)
	cd $(run_repo)/ && git checkout $(BSG_MANYCORE_COMMIT)
	cd $(run_repo)/ && git submodule update init --recursive
	ln -s $(BSG_MANYCORE_DIR)/software/riscv-tools/riscv-install/ $(run_repo)/software/riscv-tools/riscv-install

machine-gen-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
machine-gen-%: corner=$(word 1, $(subst _, ,$*))
machine-gen-%: rc_corner=$(word 2,$(subst _, ,$*))
machine-gen-%: corner_ss=$(word 3,$(subst _, ,$*))
machine-gen-%:
	mkdir -p $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) clean
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) corner=$(corner) rc_corner=$(rc_corner) CORNER_SS=$(corner_ss) build
	cp $(BSG_DESIGN_BUILD_DIR)/out/Makefile.machine.include $(machine_dir)
	cp $(BSG_DESIGN_BUILD_DIR)/out/simv* $(machine_dir)
	cp $(BSG_DESIGN_BUILD_DIR)/out/build*.log $(machine_dir)
	$(MAKE) -C $(BSG_DESIGN_BUILD_DIR) clean

run: $(foreach corner,$(CORNERS),run-$(corner))

run-%: run_dir=$(BSG_MANYCORE_DIR)/bsg_manycore_$*/software/spmd
run-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
run-%:
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) recurse-clean
	$(MAKE) -C $(run_dir) BSG_MACHINE_PATH=$(machine_dir) $(foreach test,$(REGRESS_LIST),recurse-iterate@all@$(test))

clean_all: $(foreach corner,$(CORNERS),clean-$(corner))

clean-%: run_dir=$(BSG_MANYCORE_DIR)/bsg_manycore_$*/software/spmd
clean-%:
	$(MAKE) -C $(run_dir) recurse-clean

bleach_all: $(foreach corner,$(CORNERS),bleach-$(corner))

bleach-%: run_repo=$(BSG_MANYCORE_DIR)/software/regress/bsg_manycore_$*
bleach-%: machine_dir=$(BSG_MANYCORE_DIR)/software/regress/machine-$*
bleach-%:
	-rm -rf $(run_repo)
	-rm -rf $(machine_dir)
