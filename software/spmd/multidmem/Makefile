bsg_tiles_X = 3
bsg_tiles_Y = 1


all: main.run

LIBRARY_OBJECTS += bsg_barrier_amoadd.o

KERNEL_OBJECTS+=kernel1.o
KERNEL_OBJECTS+=kernel2.o

MAIN_OBJECTS:=main.o

include ../Makefile.include

OBJECT_FILES = $(LIBRARY_OBJECTS) $(KERNEL_OBJECTS) $(MAIN_OBJECTS)
main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
