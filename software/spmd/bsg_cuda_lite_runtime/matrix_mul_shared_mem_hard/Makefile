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
	bsg_tiles_X ?= 4
	bsg_tiles_Y ?= 4


all: main.run


KERNEL_NAME ?=kernel_matrix_mul_shared_mem_hard

OBJECT_FILES=main.o kernel_matrix_mul_shared_mem_hard.o

include ../../Makefile.include


main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) ../../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../../mk/Makefile.tail_rules
