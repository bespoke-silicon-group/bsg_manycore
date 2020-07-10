bsg_tiles_X=1
bsg_tiles_Y=1

NUM_CODE_SECTIONS = 2
CODE_LABELS = _code_section_1 _code_section_2

all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -march=rv32ima -nostdlib -nostartfiles 

main.riscv: $(LINK_SCRIPT)  main.o 
	$(RISCV_LINK)  main.o -o $@ $(RISCV_LINK_OPTS)


include ../../mk/Makefile.tail_rules

