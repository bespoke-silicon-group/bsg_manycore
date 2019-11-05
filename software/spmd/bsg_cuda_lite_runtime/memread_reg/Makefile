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
	bsg_tiles_X ?= 1
	bsg_tiles_Y ?= 1

# KERNEL_DIR is the current directory
KERNEL_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

all: main.run

# It seems unnecessary to edit this makefile in two places every
# single time we create a new kernel. To simplify this process I use
# the name of this directory, as reported by KERNEL_DIR. To get the
# directory name we tokenize KERNEL_DIR using subst, and then take the
# last element in the list.
KERNEL_NAME ?= kernel_$(lastword $(subst /, ,$(KERNEL_DIR)))

OBJECT_FILES = main.o bsg_set_tile_x_y.o bsg_printf.o $(KERNEL_NAME).o

include ../../Makefile.include

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../../mk/Makefile.tail_rules
