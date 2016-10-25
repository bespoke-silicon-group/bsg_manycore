
bsg_tiles_X = 2
bsg_tiles_Y = 1

include ../Makefile.include

all: main.run

main.riscv:  main.o $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm *.o *.jou *.log *.pb bsg_rom_hello.v main.riscv *.wdb main.bin main.hex
	-rm -rf xsim.dir

main.o: Makefile










