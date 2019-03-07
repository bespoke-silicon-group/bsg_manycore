
bsg_tiles_X = 2
bsg_tiles_Y = 2
bsg_group_size = 4

# Comment below line to compile with riscv64-unknown-elf-gcc
CLANG=1
#########################################################
#each bytes defines the core type
# 00: vanilla core
# 01  vscale  core
#TYPE_VEC="64'h01_01_01_01"

all: main.run
OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o

include ../Makefile.include

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must
#     be vanilla core
BSG_FPU_OP=0

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
