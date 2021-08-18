bsg_tiles_X = 4
bsg_tiles_Y = 4

all: main.run

OBJECT_FILES=main.o interrupt.o bsg_barrier_amoadd.o

include ../Makefile.include

# number of threads per tile.
NUM_THREAD=2
RISCV_GCC_OPTS += -DNUM_THREAD=$(NUM_THREAD)
NUM_FINISH = $(NUM_THREAD)


main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
