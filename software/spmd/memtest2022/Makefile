bsg_tiles_X = $(BSG_MACHINE_GLOBAL_X)
bsg_tiles_Y = $(BSG_MACHINE_GLOBAL_Y)
NUM_FINISH = $(call bsg-times-fn,$(bsg_tiles_X),$(bsg_tiles_Y))


all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
