bsg_active_rocc_index= 0x2
bsg_tiles_X= 16
bsg_tiles_Y= 31

include ../Makefile.include

RISCV_LINK_OPTS = -m32 -march=RV32IMA -nostdlib -nostartfiles 

all: main.mem

main.riscv:  main.o 
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)

main.mem: main.hex
	sed  -n '1,8s/^/.int 0x/p' $< > $@

clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../mk/Makefile.tail_rules

