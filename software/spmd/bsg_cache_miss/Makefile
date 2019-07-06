#########################################################
#Tile group configuration
# If not configured, Will use default Values
#	bsg_tiles_org_X ?= 0
#	bsg_tiles_org_Y ?= 1
bsg_tiles_org_X =0
bsg_tiles_org_Y =1

# If not configured, Will use default Values
#	bsg_tiles_X ?= 2
#	bsg_tiles_Y ?= 2
bsg_tiles_X = 9
bsg_tiles_Y = 1


all: main.run


OBJECT_FILES=main.o

include ../Makefile.include

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
BSG_FPU_OP=0

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. -l:$(BSG_MANYCORE_LIB) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
