
bsg_tiles_X = 4
bsg_tiles_Y = 4
TRACE=1
#########################################################
#each bytes defines the core type
# 00: vanilla core
# 01  vscale  core
TYPE_VEC="64'h00_00_00_00"

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
#BSG_FPU_OP=1

RISCV_GCC_EXTRA_OPTS ?= -O2 -funroll-loops
OBJECT_FILES=main.o bsg_set_tile_x_y.o mul_div_test.o

include ../Makefile.include

all: main.run
#all: main.syn

main.riscv:  $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
