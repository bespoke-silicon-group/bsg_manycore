
bsg_tiles_X = 2
bsg_tiles_Y = 2

OBJECT_FILES = main.o

include ../Makefile.include

all: main.run

main.riscv: $(LINK_SCRIPT)  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile


include ../../mk/Makefile.tail_rules








