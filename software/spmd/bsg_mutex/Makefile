
bsg_tiles_X = 2 
bsg_tiles_Y = 5

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=main.o bsg_set_tile_x_y.o
include ../Makefile.include

all: main.run

main.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm -rf $(OBJECT_FILES) *.jou *.log *.pb bsg_rom_hello.v main.riscv *.wdb main.bin main.hex
	-rm -rf xsim.dir  csrc simv  simv.daidir  ucli.key  vcdplus.vpd bsg_manycore_io_complex_rom.v

main.o: Makefile

include ../../mk/Makefile.tail_rules
