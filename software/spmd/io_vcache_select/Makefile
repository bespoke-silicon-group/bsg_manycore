# The program runs on one tile of the first pod, and reaches the vcaches of
# every pod from there.
override bsg_pods_X = 1
override bsg_pods_Y = 1

bsg_tiles_X = 1
bsg_tiles_Y = 1


all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

# The width of an x coordinate gives the layout of the pod register.
RISCV_GCC_OPTS += -DX_CORD_WIDTH=$(BSG_MACHINE_X_CORD_WIDTH)

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
