bsg_tiles_X= 2 
bsg_tiles_Y= 1 


all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)

include ../../mk/Makefile.tail_rules

