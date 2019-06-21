bsg_tiles_X= 1
bsg_tiles_Y= 1 

all: main.run

LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/link_dram.ld

include ../Makefile.include

RISCV_LINK_OPTS =  -march=rv32ima -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)

include ../../mk/Makefile.tail_rules
