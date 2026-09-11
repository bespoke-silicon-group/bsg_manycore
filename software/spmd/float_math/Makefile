bsg_tiles_X = 1
bsg_tiles_Y = 1

# This test checks the exact bits produced by source-order FP32 reductions.
# Keep the surrounding SDK fast-math policy, but do not permit reassociation or
# reciprocal replacement to change the numerical contract being tested.
RISCV_GCC_EXTRA_OPTS += -fno-associative-math -fno-reciprocal-math

all: main.run


OBJECT_FILES=main.o

include ../Makefile.include


main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
