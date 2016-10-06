
bsg_tiles_X = 2
bsg_tiles_Y = 2



all: main.run

include ../Makefile.include


main.riscv:  main.o $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v main.riscv *.wdb main.bin main.hex
	-rm -rf xsim.dir
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd

dve64:
	$(VCS_BIN)/dve -full64

main.o: Makefile










