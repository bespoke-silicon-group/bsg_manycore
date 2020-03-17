
bsg_tiles_X = 2
bsg_tiles_Y = 2

OBJECT_FILES = hello.o 

include ../Makefile.include

all: hello.run

hello.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


hello.o: Makefile


include ../../mk/Makefile.tail_rules



