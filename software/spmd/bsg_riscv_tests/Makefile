find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

RVTEST_DIR=$(BSG_MANYCORE_DIR)/imports/riscv-tests/isa

NO-RECURSE = fence_i amoadd_w amo amoadd_w amoand_w amomax_w amomaxu_w amomin_w amominu_w amoor_w amoxor_w amoswap_w lrsc \
	mulh mulhsu mulhu	

# not selected rv32mi rv32si rv32ua rv32uc rv32ud rv64mi rv64si rv64ua rv64uc rv64ud rv64uf rv64ui rv64um
export RVTEST_ISA_VARIANTS = rv32ui rv32uf rv32um

# get test names, filter the ones we don't want to run

RVTEST_INSTS = $(filter-out $(NO-RECURSE),$(basename $(notdir $(foreach x,$(RVTEST_ISA_VARIANTS),$(shell /usr/bin/find $(RVTEST_DIR)/$(x) -iname *.S)))))

$(warning RVTEST_INSTS = $(RVTEST_INSTS))

all: $(foreach instr, $(RVTEST_INSTS), $(instr).riscv_tests_run)
	$(warning Finished running: $(TEST_INSTS))


# Not piped through tee, which would hide the exit status of a failing subtest.
%.riscv_tests_run: check_riscv_tests
	mkdir -p $*_run
	$(MAKE) -C $*_run -f ../Makefile.include $*.run > $*_run/$*-run.log 2>&1; \
	  status=$$?; cat $*_run/$*-run.log; exit $$status

# The tests are built from the riscv-tests import as it is. An earlier version
# of this Makefile patched the fflags and fcsr checks out of two of its files.
# An import that still has such changes would skip those checks, so stop.
RVTEST_WAS_PATCHED = isa/macros/scalar/test_macros.h isa/rv64uf/move.S

.PHONY: check_riscv_tests
check_riscv_tests:
	@if git -C $(RVTEST_DIR)/.. rev-parse --git-dir > /dev/null 2>&1 \
	    && ! git -C $(RVTEST_DIR)/.. diff --quiet HEAD -- $(RVTEST_WAS_PATCHED); then \
	  echo "$(abspath $(RVTEST_DIR)/..) has local changes, perhaps from an earlier version of this Makefile."; \
	  echo "Inspect the changes first:"; \
	  echo "  git -C $(abspath $(RVTEST_DIR)/..) diff HEAD -- $(RVTEST_WAS_PATCHED)"; \
	  echo "To discard all staged and unstaged changes in these two files:"; \
	  echo "  git -C $(abspath $(RVTEST_DIR)/..) checkout HEAD -- $(RVTEST_WAS_PATCHED)"; \
	  echo "Then run 'make clean' here before running the tests again."; \
	  exit 1; \
	fi

%.dve:
	cd $*_run; make -f ../Makefile.include dve

%.dis:
	$(MAKE) -C $*_run -f ../Makefile.include $*.dis > dis

clean:
	-rm -rf *_run
	-rm -rf *.touchfile
