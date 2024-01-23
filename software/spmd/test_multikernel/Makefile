bsg_tiles_X = 4
bsg_tiles_Y = 2

all: main.run

# library functions
LIBRARY_OBJECTS += bsg_barrier_amoadd.o

# kernel functions
KERNEL_OBJECTS += kernel0.o
KERNEL_OBJECTS += kernel1.o
KERNEL_OBJECTS += kernel2.o
KERNEL_OBJECTS += kernel3.o
KERNEL_OBJECTS += kernel4.o
KERNEL_OBJECTS += kernel5.o
KERNEL_OBJECTS += kernel6.o
KERNEL_OBJECTS += kernel7.o

# Main function
MAIN_OBJECTS = main.o

include ../Makefile.include

# Main build rule, most likely unmodified
OBJECT_FILES = $(LIBRARY_OBJECTS) $(KERNEL_OBJECTS) $(MAIN_OBJECTS)
main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

# Additional dependency to rebuild from makefile
main.o: Makefile

# Special rules to build kernels
kernel0.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=0
kernel1.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=1
kernel2.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=2
kernel3.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=3
kernel4.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=4
kernel5.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=5
kernel6.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=6
kernel7.o: RISCV_GXX_EXTRA_OPTS += -DTEST_VAR=7

# Global rules
RISCV_GXX_EXTRA_OPTS += -DNUM_KERNELS=8 -DBUFFER_SIZE=64

include ../../mk/Makefile.tail_rules
