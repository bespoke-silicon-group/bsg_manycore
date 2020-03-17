.DEFAULT_GOAL = all

override bsg_tiles_X = 4 
override bsg_tiles_Y = 8 
MASTER_X   ?= 2
MASTER_Y   ?= 2

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops -DMASTER_X=$(MASTER_X) -DMASTER_Y=$(MASTER_Y)
OBJECT_FILES=main.o
include ../Makefile.include

all: main.run

main.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile


include ../../mk/Makefile.tail_rules
