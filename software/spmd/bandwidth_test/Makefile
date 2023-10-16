bsg_tiles_X = 16
bsg_tiles_Y = 2

# TODO: Set me
RISCV_GCC_EXTRA_OPTS += -O3
RISCV_GCC_EXTRA_OPTS += -DITERATIONS=10
RISCV_GCC_EXTRA_OPTS += -DSTREAM_SIZE_MB=4
RISCV_GCC_EXTRA_OPTS += -DDRAM_BASE=0x82000000

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
