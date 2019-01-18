bsg_tiles_X= 2
bsg_tiles_Y= 2 

all: main.run

# Rule to write processor execution logs. To be used after the
# verilog simulation.
#
# Redirects verilog standard output starting with "X<x_cord>_Y<y_cord>.pelog" 
# to a unique log file for each coordinate in the manycore. This can be useful 
# for a quick debug of processor or program running on it.
proc_exe_logs: X0_Y0.pelog X1_Y0.pelog X0_Y1.pelog X1_Y1.pelog

include ../Makefile.include

RISCV_LINK_OPTS =  -march=rv32ima -nostdlib -nostartfiles 

main.riscv:  main.o 
	$(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/asm.ld  $< -o $@ $(RISCV_LINK_OPTS)


clean:
	-rm -rf *.o *.jou *.log *.pb bsg_manycore_io_complex_rom.v *.riscv *.wdb *.bin *.hex *.vec
	-rm -rf xsim.dir *.mem
	-rm -rf ./simv csrc simv.daidir ucli.key DVEfiles *.vpd


include ../../mk/Makefile.tail_rules

