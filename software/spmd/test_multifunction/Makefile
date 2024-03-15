bsg_tiles_X = 2
bsg_tiles_Y = 1

RISCV_GXX_EXTRA_OPTS += -DNUM_KERNELS=2 -DBUFFER_SIZE=64

all: main.run

OBJECT_FILES=main.o bsg_barrier_amoadd.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
