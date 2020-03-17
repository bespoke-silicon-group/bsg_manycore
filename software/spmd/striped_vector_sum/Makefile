
bsg_tiles_X = 2
bsg_tiles_Y = 2
bsg_group_size = $(shell echo "$(bsg_tiles_X) * $(bsg_tiles_Y)" | bc)

# Comment below line to compile with riscv64-unknown-elf-gcc
CLANG=1

all: main.run
OBJECT_FILES=main.o

include ../Makefile.include

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
