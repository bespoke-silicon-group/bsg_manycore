BSG_MANYCORE_DIR ?= ../../..

bsg_tiles_X = 1
bsg_tileS_Y = 1

OBJECT_FILES := main.o

include $(BSG_MANYCORE_DIR)/software/spmd/Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS)
	$(RISCV_LINK)  $(filter %.o, $^) -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules
