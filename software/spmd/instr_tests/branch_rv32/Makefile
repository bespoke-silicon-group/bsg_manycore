NUM_CODE_SECTIONS = 2
CODE_LABELS = _code_section_1 _code_section_2

all: main.run

include ../../Makefile.include

RISCV_LINK_OPTS = -march=rv32ima -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_LINK)  $< -o $@ $(RISCV_LINK_OPTS)


clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../../mk/Makefile.tail_rules

