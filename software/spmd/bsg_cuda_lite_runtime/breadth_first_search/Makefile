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


OBJECT_FILES=main.o bsg_set_tile_x_y.o kernel_bfs.o csr_setup_graph_data.o

include ../../Makefile.include

INCS := -I$(BSG_MANYCORE_DIR)/../hbgraphs/include/device
INCS += -I$(BSG_MANYCORE_DIR)/../hbgraphs/include/common

vpath %.cpp $(BSG_MANYCORE_DIR)/../hbgraphs/src/device
vpath %.c   $(BSG_MANYCORE_DIR)/../hbgraphs/src/device

OPT_LEVEL := -O3

RISCV_GXX_EXTRA_OPTS := -fpermissive

.PHONY: debug
debug:
	@echo $(RISCV_GXX_EXTRA_OPTS)

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../../mk/Makefile.tail_rules
