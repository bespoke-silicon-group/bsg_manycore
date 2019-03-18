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
bsg_hetero_type_vec =  0, 0, 0, 0,  \
		       0, 0, 0, 0,  \
		       0, 0, 0, 0,  \
                       1, 1, 1, 1
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

# Rule to write processor execution logs. To be used after the
# verilog simulation.
#
# Redirects verilog standard output starting with "X<x_cord>_Y<y_cord>.pelog" 
# to a unique log file for each coordinate in the manycore. This can be useful 
# for a quick debug of processor or program running on it.
proc_exe_logs: X0_Y0.pelog X1_Y0.pelog

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
