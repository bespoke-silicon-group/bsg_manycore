bsg_tiles_X = 1
bsg_tiles_Y = 5

BSG_PLATFORM ?= xcelium
BSG_MACHINE_PATH ?= $(CURDIR)/machine

all: main.run

OBJECT_FILES = main.o

include ../Makefile.include

.PHONY: check-config machine
check-config:
	@test "$(BSG_PLATFORM)" = xcelium \
	  && test "$(BSG_MACHINE_NETWORK_CFG)" = e_network_half_ruche_x \
	  && test "$(BSG_MACHINE_RUCHE_FACTOR_Y)" = 18 \
	  && test "$(BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y)" = 2 \
	  && test "$(BSG_MACHINE_PODS_X)" = 1 \
	  && test "$(BSG_MACHINE_PODS_Y)" = 1 \
	  && test "$(BSG_MACHINE_GLOBAL_X)" = 4 \
	  && test "$(BSG_MACHINE_GLOBAL_Y)" = 8 \
	  && test "$(BSG_MACHINE_ORIGIN_X_CORD)" = 4 \
	  && test "$(BSG_MACHINE_ORIGIN_Y_CORD)" = 8 \
	  && test "$(BSG_MACHINE_HOST_X_CORD)" = 4 \
	  && test "$(BSG_MACHINE_HOST_Y_CORD)" = 0 \
	  && test "$(bsg_tiles_X)" = 1 \
	  && test "$(bsg_tiles_Y)" = 5 \
	  || { echo "This test requires Xcelium and its supplied Y-ruche machine configuration"; exit 1; }

machine:
	$(MAKE) -C $(BSG_MANYCORE_DIR)/machines BSG_PLATFORM=$(BSG_PLATFORM) $(BSG_SIM_EXE)

main.run: NBF_FILE = main.nbf
main.run: check-config main.nbf machine
	$(BSG_SIM_EXE) $(BSG_SIM_OPTS)
	@grep -q 'RECEIVED BSG_FINISH PACKET from all pods' xmsim.log \
	  && ! grep -Eq 'BSG_TIMEOUT|BSG_FAIL|\[BSG_ERROR\]|\*E,|\*F,' xmsim.log \
	  || { echo "Y barrier test failed or timed out; see xmsim.log"; exit 1; }

main.riscv: check-config $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
