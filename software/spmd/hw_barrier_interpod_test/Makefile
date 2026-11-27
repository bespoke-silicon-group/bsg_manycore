# One tile group covering each whole pod, launched in every pod.
bsg_tiles_X = $(BSG_MACHINE_GLOBAL_X)
bsg_tiles_Y = $(BSG_MACHINE_GLOBAL_Y)

override bsg_pods_X = $(BSG_MACHINE_PODS_X)
override bsg_pods_Y = $(BSG_MACHINE_PODS_Y)

BSG_MACHINE_PATH ?= $(abspath $(CURDIR)/../../../machines/pod_2x2_full_8X16Y)

all: main.run

OBJECT_FILES = main.o bsg_barrier_amoadd.o

include ../Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
