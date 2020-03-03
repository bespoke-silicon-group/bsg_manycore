
bsg_tiles_X = 2
bsg_tiles_Y = 2

OBJECT_FILES = hello.o bsg_set_tile_x_y.o

include ../Makefile.include

all: hello.run

hello.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)


hello.o: Makefile


include ../../mk/Makefile.tail_rules








