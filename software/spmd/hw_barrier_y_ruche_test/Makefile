# One column of 2R+1 tiles, R = the machine's Y barrier ruche factor.
bsg_tiles_X = 1
bsg_tiles_Y = $(shell expr 2 \* $(BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y) + 1)

BSG_MACHINE_PATH ?= $(abspath $(CURDIR)/../../../machines/pod_1x1_full)

all: main.run

OBJECT_FILES = main.o

include ../Makefile.include

.PHONY: check-config
check-config:
	@test "$(BSG_MACHINE_NETWORK_CFG)" = e_network_full_ruche_xy \
	  && test "$(BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y)" -ge 2 \
	  && test "$(bsg_tiles_Y)" -le "$(BSG_MACHINE_GLOBAL_Y)" \
	  || { echo "This test requires an e_network_full_ruche_xy machine with BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y >= 2 and at least 2*BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y+1 rows"; exit 1; }

main.riscv: check-config $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
