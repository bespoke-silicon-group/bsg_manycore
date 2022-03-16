BSG_MANYCORE_DIR ?= ../../../
BSG_LIB_DIR = ${BSG_MANYCORE_DIR}/software/bsg_manycore_lib
C_PORT_DIR = ${PROJECTS_DIR}/c-port-dev/DDL

bsg_tiles_X=4
bsg_tiles_Y=2
bsg_global_X=4
bsg_global_Y=2
BSG_MACHINE_HOST_X_CORD = 4
BSG_MACHINE_HOST_Y_CORD = 0

# CC=gcc

BSG_FLAGS=-D bsg_tiles_X=${bsg_tiles_X} -D bsg_tiles_Y=${bsg_tiles_Y}
BSG_FLAGS+=-D bsg_global_X=${bsg_global_X} -D bsg_global_Y=${bsg_global_Y}
BSG_FLAGS+=-D IO_X_INDEX=${BSG_MACHINE_HOST_X_CORD} -D IO_Y_INDEX=${BSG_MACHINE_HOST_Y_CORD}
INCS+=-I ${BSG_LIB_DIR} -I ${C_PORT_DIR}/headers
BINARIES=main.o

all: main.run

OBJECT_FILES= ${BINARIES}

include $(BSG_MANYCORE_DIR)/software/spmd/Makefile.include

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: main.c
	$(RISCV_GCC) ${BSG_FLAGS} ${INCS} -c main.c

include $(BSG_MANYCORE_DIR)/software/mk/Makefile.tail_rules

fresh: clean
	rm -rf fft_parallel
	clear
