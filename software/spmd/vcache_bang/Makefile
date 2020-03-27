bsg_tiles_X = 2
bsg_tiles_Y = 2
MAX_CYCLES = 10000000

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

RISCV_GCC_OPTS += -D__bsg_vcache_size=$(BSG_ELF_VCACHE_SIZE)

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
