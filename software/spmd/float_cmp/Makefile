bsg_tiles_X = 1
bsg_tiles_Y = 1


all: main.run


OBJECT_FILES=main.o

include ../Makefile.include

# This makes sure compiler doesn't perform unsafe optimizations with
# INFs and NaNs.
RISCV_GCC_EXTRA_OPTS = -fno-fast-math

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
