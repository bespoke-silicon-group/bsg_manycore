bsg_tiles_X = 1
bsg_tiles_Y = 1

N = 1 2 3 4 5 6 7 8 9 10 \
    11 12 13 14 15 16 17 18 19 20

all: $(foreach n,$(N),$(n).nrun)

%.nrun: RISCV_GCC_EXTRA_OPTS += -DN=$*
%.nrun: main.run


OBJECT_FILES=main.o

include ../Makefile.include

ifeq ($(DEBUG),1)
	RISCV_GCC_EXTRA_OPTS = -g
	RISCV_LINK_OPTS += -g
endif

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
