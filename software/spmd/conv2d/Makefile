bsg_tiles_X ?= 16
bsg_tiles_Y ?= 8
ITERATIONS ?= 1
NOP_WAIT ?= 1000000

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

RISCV_GCC_EXTRA_OPTS += -DITERATIONS=$(ITERATIONS) -DNOP_WAIT=$(NOP_WAIT)

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
