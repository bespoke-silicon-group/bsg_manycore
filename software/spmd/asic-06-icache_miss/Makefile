bsg_tiles_X= 1
bsg_tiles_Y= 1 

all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -march=rv32imaf -nostdlib -nostartfiles 

main.riscv: $(LINK_SCRIPT)  main.o 
	$(RISCV_LINK)  main.o -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules

