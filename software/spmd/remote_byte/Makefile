
bsg_tiles_X = 2
bsg_tiles_Y = 2

include ../Makefile.include

all: main.run

main.riscv: $(LINK_SCRIPT)  main.o $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) main.o -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules









