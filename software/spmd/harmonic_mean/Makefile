bsg_tiles_X = 1
bsg_tiles_Y = 1


# The expected harmonic mean is an exact FP32 bit pattern. Preserve the source
# reduction order while retaining the surrounding SDK fast-math policy.
RISCV_GCC_EXTRA_OPTS += -fno-associative-math

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
