bsg_tiles_X = 4
bsg_tiles_Y = 2

all: main.run

OBJECT_FILES := main.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB)
	$(RISCV_LINK)  $(filter %.o, $^) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules
