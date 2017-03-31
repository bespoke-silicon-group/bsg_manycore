all: main.run

include ../Makefile.include

RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v main.riscv *.wdb main.bin main.hex main.vec
	-rm -rf xsim.dir
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd

main.o: Makefile

include ../../mk/Makefile.tail_rules
