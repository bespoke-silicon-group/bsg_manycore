
bsg_tiles_X = 4
bsg_tiles_Y = 1

# configure which heterogeneous cores go where
# 02..FF = your custom type
# 01 = bsg_manycore_accel_default
# 00 = bsg_manycore_proc

VLOG_EXTRA = -d BSG_HETERO_TYPE_VEC="64'h01_01_01_00"

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=main.o bsg_set_tile_x_y.o
include ../Makefile.include

all: main.run

main.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm $(OBJECT_FILES) *.jou *.log *.pb bsg_rom_main.v main.riscv *.wdb main.bin main.hex
	-rm -rf xsim.dir

main.o: Makefile










