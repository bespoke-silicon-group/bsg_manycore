
bsg_tiles_X = 2
bsg_tiles_Y = 2

include ../Makefile.include

all: hello.run

hello.riscv:  hello.o $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_rom_hello.v hello.riscv *.wdb hello.bin hello.hex
	-rm -rf xsim.dir
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd

dve64:
	$(VCS_BIN)/dve -full64

hello.o: Makefile










