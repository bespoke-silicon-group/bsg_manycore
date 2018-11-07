bsg_tiles_X= 2 
bsg_tiles_Y= 2 

FSB_X_CORD ?=0
RISCV_GCC_EXTRA_OPTS ?= -DFSB_X_CORD=$(FSB_X_CORD) 
#-------------------------------------------------------------------------
all: main.run

include ../Makefile.include
RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)


clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../mk/Makefile.tail_rules

