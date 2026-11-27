bsg_tiles_X = 1
bsg_tiles_Y = 5

# main.c checks the configuration generated for Y barrier ruche factor 2.
BSG_MACHINE_PATH ?= $(abspath $(CURDIR)/../../../machines/pod_1x1_full)

all: main.run

OBJECT_FILES = main.o

include ../Makefile.include

.PHONY: check-config
check-config:
	@test "$(BSG_MACHINE_NETWORK_CFG)" = e_network_full_ruche_xy \
	  && test "$(BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y)" = 2 \
	  || { echo "This test requires an e_network_full_ruche_xy machine with BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y = 2"; exit 1; }

main.riscv: check-config $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
