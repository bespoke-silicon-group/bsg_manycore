bsg_tiles_X= 1
bsg_tiles_Y= 1 

all: main.run


include ../Makefile.include

RISCV_LINK_OPTS =  -march=rv32ima -nostdlib -nostartfiles 

main.riscv: $(LINK_SCRIPT)  main.o 
	$(RISCV_LINK) main.o -o $@ $(RISCV_LINK_OPTS)


clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../mk/Makefile.tail_rules

