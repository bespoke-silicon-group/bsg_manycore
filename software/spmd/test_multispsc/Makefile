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
kernel0.o: RISCV_GXX_EXTRA_OPTS += ""
kernel1.o: RISCV_GXX_EXTRA_OPTS += ""
kernel2.o: RISCV_GXX_EXTRA_OPTS += ""
kernel3.o: RISCV_GXX_EXTRA_OPTS += ""
kernel4.o: RISCV_GXX_EXTRA_OPTS += ""
kernel5.o: RISCV_GXX_EXTRA_OPTS += ""
kernel6.o: RISCV_GXX_EXTRA_OPTS += ""
kernel7.o: RISCV_GXX_EXTRA_OPTS += ""

# Global rules
RISCV_GXX_EXTRA_OPTS += -DBUFFER_ELS=24 -DCHAIN_LEN=8 -DNUM_PACKETS=10

include ../../mk/Makefile.tail_rules
