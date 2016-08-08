
bsg_tiles_X = 2
bsg_tiles_Y = 2

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=hello.o bsg_set_tile_x_y.o load_store_test.o move_test.o \
bypass_alu_fpi_test.o bypass_fpi_fpi_test.o bypass_fpi_alu_test.o \
cvt_sgn_class_test.o
include ../Makefile.include

all: hello.run

hello.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)

clean:
	-rm $(OBJECT_FILES) *.jou *.log *.pb bsg_rom_hello.v hello.riscv *.wdb hello.bin hello.hex
	-rm -rf xsim.dir

hello.o: Makefile










