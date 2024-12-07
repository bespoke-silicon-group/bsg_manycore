bsg_tiles_X ?= 16
bsg_tiles_Y ?= 8
NUM_FINISH = $(call bsg-times-fn,$(bsg_tiles_X),$(bsg_tiles_Y))

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES)
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
