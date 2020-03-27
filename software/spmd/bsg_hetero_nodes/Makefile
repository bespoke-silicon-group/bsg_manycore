#########################################################
# Network Configutaion
# If not configured, Will use default Values
#	bsg_global_X ?= $(bsg_tiles_X)
#	bsg_global_Y ?= $(bsg_tiles_Y)+1
bsg_global_X = 4
bsg_global_Y = 4

# Configure the types of each nodes in the network
# Refer to bsg_manycore/v/bsg_manycore_hetero_socket.v for type definiation
#
# If not configured, Will use default Values
# 	bsg_hetero_type_vec = 0
#
# The first row is assigned to IO router and will the configuration values are ignored.
bsg_hetero_type_vec =  {0, 0, 0, 0},  \
		       {0, 0, 0, 0},  \
		       {0, 0, 0, 0},  \
                       {1, 1, 1, 1}
#########################################################
#Tile group configuration
# If not configured, Will use default Values
#	bsg_tiles_org_X ?= 0
#	bsg_tiles_org_Y ?= 1
bsg_tiles_org_X =1
bsg_tiles_org_Y =1

# If not configured, Will use default Values
#	bsg_tiles_X ?= 2
#	bsg_tiles_Y ?= 2
bsg_tiles_X = 2
bsg_tiles_Y = 2


all: main.run


OBJECT_FILES=main.o

include ../Makefile.include


main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
