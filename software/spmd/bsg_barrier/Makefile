
bsg_tiles_X = 3 
bsg_tiles_Y = 3

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=main.o
include ../Makefile.include

all: main.run

main.riscv: $(LINK_SCRIPT)  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm -rf $(OBJECT_FILES) *.jou *.log *.pb bsg_rom_hello.v main.riscv *.wdb main.bin main.hex
	-rm -rf xsim.dir  csrc simv  simv.daidir  ucli.key  vcdplus.vpd bsg_manycore_io_complex_rom.v

main.o: Makefile

include ../../mk/Makefile.tail_rules
