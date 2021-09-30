bsg_tiles_X = 1
bsg_tiles_Y = 1


all: main.run


OBJECT_FILES=main.o

include ../Makefile.include

RISCV_GCC_OPTS += -fno-threadsafe-statics -ffp-contract=off -lm -g -std=c++14
RISCV_LINK_OPTS += -ffast-math -lc -lm

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
