
bsg_tiles_X = 2
bsg_tiles_Y = 2
bsg_group_size = 4

# Comment below line to compile with riscv64-unknown-elf-gcc
CLANG=1

all: main.run
OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o

include ../Makefile.include


main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
