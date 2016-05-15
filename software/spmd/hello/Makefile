
bsg_tiles_X = 2
bsg_tiles_Y = 2

include ../Makefile.include

all: hello.run

hello.riscv:  hello.o $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm *.o *.jou *.log *.pb bsg_rom_hello.v hello.riscv *.wdb hello.bin hello.hex
	-rm -rf xsim.dir

hello.o: Makefile










