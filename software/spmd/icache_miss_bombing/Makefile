bsg_tiles_X = $(BSG_MACHINE_GLOBAL_X)
bsg_tiles_Y = $(BSG_MACHINE_GLOBAL_Y)
NUM_FINISH = $(call bsg-times-fn,$(bsg_tiles_X),$(bsg_tiles_Y))


all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles 

main.riscv: $(LINK_SCRIPT)  main.o 
	$(RISCV_LINK)  main.o -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules

