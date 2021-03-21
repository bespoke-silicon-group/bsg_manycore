MAX_CYCLES=100000000
NUM_FINISH=32 # each tile sends a finish packet.

bsg_tiles_org_X ?=0
bsg_tiles_org_Y ?=3
bsg_tiles_X=16
bsg_tiles_Y=2

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
