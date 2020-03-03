bsg_tiles_X= 4
bsg_tiles_Y= 4 

all: main.run

include ../Makefile.include

RISCV_LINK_OPTS =  -march=rv32ima -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_LINK) $< -o $@ $(RISCV_LINK_OPTS)


clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../mk/Makefile.tail_rules

