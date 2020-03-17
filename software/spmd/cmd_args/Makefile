BSG_NEWLIB = 1
bsg_tiles_X = 1
bsg_tiles_Y = 1

MAX_CYCLES=100000000

ifdef SPIKE

RISCV_GCC_EXTRA_OPTS += -D__spike__
SPMD_COMMON_OBJECTS += spike.o

endif

LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/link_dram.ld

all: main.run

OBJECT_FILES=main.o
IN_FILES=
ARGC=2
ARGV=foo bar

ifdef DEBUG
	RISCV_EXTRA_OPTS += -g
	RISCV_EXTRA_OPTS += -O0
endif

include ../Makefile.include

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) $(CRT_OBJ)
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
