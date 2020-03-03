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


KERNEL_NAME ?=kernel_conv1d

OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o kernel_conv1d.o

include ../../Makefile.include


RISCV_LINK_OPTS:=$(filter-out -nostdlib,$(RISCV_LINK_OPTS))
main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../../mk/Makefile.tail_rules
