#########################################################
# Network Configutaion
# If not configured, Will use default Values
	bsg_global_X ?= $(bsg_tiles_X)
	bsg_global_Y ?= $(bsg_tiles_Y)+1

#########################################################
#Tile group configuration
# If not configured, Will use default Values
	bsg_tiles_org_X ?= 0
	bsg_tiles_org_Y ?= 1

# If not configured, Will use default Values
	bsg_tiles_X ?= 2
	bsg_tiles_Y ?= 2


all: main.run


RISCV_GXX_EXTRA_OPTS +=-I/mnt/users/ssd0/homes/eafurst/graphit/src/runtime_lib/hammerblade/device/ -Wall

KERNEL_NAME ?=kernel_bfs_pull

OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o kernel_bfs_pull.o

include ../../Makefile.include


main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../../mk/Makefile.tail_rules
