#CLANG=1
TRACE=1

all: spmd.run

UBMK_OBJS = gups.o
OBJECT_FILES = spmd_tb_main.o cuda_tb_main.o $(UBMK_OBJS)

OPT_LEVEL := -O3

include ../Makefile.include
RISCV_GCC_OPTS += -funroll-loops -ffast-math

gups.o: RISCV_GCC_OPTS += -ffreestanding

$(OBJECT_FILES): config.h
spmd.riscv: spmd_tb_main.o
main.riscv: cuda_tb_main.o
main.riscv spmd.riscv: $(UBMK_OBJS)
main.riscv spmd.riscv: $(LINK_SCRIPT) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(filter $^,$(OBJECT_FILES)) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)


$(OBJECT_FILES): Makefile

include ../../mk/Makefile.tail_rules
