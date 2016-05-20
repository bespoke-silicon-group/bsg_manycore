
bsg_tiles_X = 2
bsg_tiles_Y = 2

OBJECT_FILES = hello.o 

include ../Makefile.include

all: hello.run

hello.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm $(OBJECT_FILES) *.jou *.log *.pb bsg_rom_hello.v hello.riscv *.wdb hello.bin hello.hex
	-rm -rf xsim.dir

hello.o: Makefile










