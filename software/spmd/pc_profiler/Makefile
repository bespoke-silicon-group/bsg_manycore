bsg_tiles_X = 4
bsg_tiles_Y = 4

HIST_SPACE ?= 4096

all: main.run

OBJECT_FILES=main.o profiler.o

include ../Makefile.include

RISCV_GCC_OPTS += -DHIST_SPACE=$(HIST_SPACE)

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
