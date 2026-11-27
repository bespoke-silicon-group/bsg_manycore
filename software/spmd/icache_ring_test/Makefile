bsg_tiles_X= 1
bsg_tiles_Y= 1

all: main.run

include ../Makefile.include

# Ring length: one more loop than the icache has ways, so every visit misses.
RING ?= $(shell expr $(or $(BSG_MACHINE_ICACHE_WAYS),1) + 1)
RISCV_GCC_EXTRA_OPTS += -DRING=$(RING)

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles

main.o: Makefile

main.riscv: $(LINK_SCRIPT)  main.o 
	$(RISCV_LINK)  main.o -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules
