export BSG_MANYCORE_DIR := $(shell git rev-parse --show-toplevel)
bsg_tiles_X=1
bsg_tiles_Y=1

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.master
include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles -mno-relax

LOOP_SIZES = $(shell seq 2 32)
all: $(addsuffix _run, $(LOOP_SIZES))

%.riscv: $(LINK_SCRIPT) %.o
	$(RISCV_LINK) $*.o -o $@ $(RISCV_LINK_OPTS)

%_run:
	mkdir -p $@
	python main.py $* > $@/main.S
	$(MAKE) -C $@ -f ../Makefile main.run

%_dis:
	$(MAKE) -C $*_run -f ../Makefile main.dis

clean:
	rm -rf *_run
