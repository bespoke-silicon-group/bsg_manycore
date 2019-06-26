BSG_MACHINE_PATH = $(BSG_MANYCORE_DIR)/machines/1x1
BSG_ELF_DEFAULT_DATA_LOC = SHARED
BSG_NEWLIB = 1
bsg_tiles_X = 1
bsg_tiles_Y = 1

#########################################################
#each bytes defines the core type
# 00: vanilla core
# 01  vscale  core
#TYPE_VEC="64'h01_01_01_01"

ifdef SPIKE

all: main.spike

RISCV_GCC_EXTRA_OPTS += -D__spike__
LINK_SCRIPT = $(BSG_MANYCORE_DIR)/software/spmd/common/spike.ld

else

all: main.run

endif

OBJECT_FILES=main.o
IN_FILES=hello.txt

ifdef DEBUG
	RISCV_EXTRA_OPTS += -g
	RISCV_EXTRA_OPTS += -O0
endif

include ../Makefile.include

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
BSG_FPU_OP=0

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. -l:$(BSG_MANYCORE_LIB) -o $@ $(RISCV_LINK_OPTS) -l:$(BSG_MANYCORE_LIB)


main.o: Makefile

include ../../mk/Makefile.tail_rules
