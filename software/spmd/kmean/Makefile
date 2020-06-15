bsg_tiles_X = 1
bsg_tiles_Y = 1

all: main.run

OBJECT_FILES=main.o

include ../Makefile.include

# remove -nostdlib, so we can use sqrt()
_RISCV_LINK_OPTS = $(subst -nostdlib, , $(RISCV_LINK_OPTS))

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(_RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
