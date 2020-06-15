find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

RVTEST_DIR=$(BSG_MANYCORE_DIR)/imports/riscv-tests/isa
RVTEST_PATCHES=test_macros.patch rv32uf.move.patch

NO-RECURSE = fence_i amoadd_w amo amoadd_w amoand_w amomax_w amomaxu_w amomin_w amominu_w amoor_w amoxor_w amoswap_w lrsc \
	mulh mulhsu mulhu	

# not selected rv32mi rv32si rv32ua rv32uc rv32ud rv64mi rv64si rv64ua rv64uc rv64ud rv64uf rv64ui rv64um
export RVTEST_ISA_VARIANTS = rv32ui rv32uf rv32um

# get test names, filter the ones we don't want to run

RVTEST_INSTS = $(filter-out $(NO-RECURSE),$(basename $(notdir $(foreach x,$(RVTEST_ISA_VARIANTS),$(shell /usr/bin/find $(RVTEST_DIR)/$(x) -iname *.S)))))

$(warning RVTEST_INSTS = $(RVTEST_INSTS))

all: $(foreach instr, $(RVTEST_INSTS), $(instr).riscv_tests_run)
	$(warning Finished running: $(TEST_INSTS))


%.riscv_tests_run: patch_riscv_tests.touchfile
	mkdir -p $*_run
	$(MAKE) -C $*_run -f ../Makefile.include $*.run 2>&1 | /usr/bin/tee $*_run/$*-run.log

patch_riscv_tests.touchfile: $(RVTEST_PATCHES)
	cd $(RVTEST_DIR)/.. && git apply $(foreach patch,$(RVTEST_PATCHES),$(BSG_MANYCORE_DIR)/software/spmd/bsg_riscv_tests/$(patch))
	touch $@

%.dve:
	cd $*_run; make -f ../Makefile.include dve

%.dis:
	$(MAKE) -C $*_run -f ../Makefile.include $*.dis > dis

clean:
	-rm -rf *_run
	-rm -rf *.touchfile
	cd $(RVTEST_DIR)/.. && git apply -R $(foreach patch,$(RVTEST_PATCHES),$(BSG_MANYCORE_DIR)/software/spmd/bsg_riscv_tests/$(patch))
