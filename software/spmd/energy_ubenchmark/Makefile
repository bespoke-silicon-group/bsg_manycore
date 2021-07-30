export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
bsg_tiles_X= 1
bsg_tiles_Y= 1 

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules
include $(BSG_MANYCORE_DIR)/software/spmd/energy_ubenchmark/Makefile.testlist

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles -mno-relax

all: $(addsuffix _run, $(ENERGY_UBENCHMARK))

%.riscv: $(LINK_SCRIPT) %.o
	$(RISCV_LINK) $*.o -o $@ $(RISCV_LINK_OPTS)

%_run:
	mkdir -p $@
	cp $*.S $@/main.S
	$(MAKE) -C $@ -f ../Makefile main.run

clean:
	rm -rf *run bsg_link.ld
