bsg_tiles_X = 2
bsg_tiles_Y = 5

#########################################################
#each bytes defines the core type
# 00: vanilla core
# 01  vscale  core
#TYPE_VEC="64'h01_01_01_01"

all: main.run

# Rule to write processor execution logs. To be used after the
# verilog simulation.
#
# Redirects verilog standard output starting with "X<x_cord>_Y<y_cord>.pelog" 
# to a unique log file for each coordinate in the manycore. This can be useful 
# for a quick debug of processor or program running on it.
proc_exe_logs: X1_Y4.pelog

OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o \
			  lfs.o lfs_util.o lfs_bd.o

include ../Makefile.include

LFS_DIR = $(BSG_MANYCORE_DIR)/software/littlefs/lfs # file system
BD_DIR = $(BSG_MANYCORE_DIR)/software/littlefs/bd # block device
vpath %.c $(LFS_DIR) $(BD_DIR)

RISCV_GCC_OPTS += -I$(LFS_DIR) -I$(BD_DIR) -DLFS_NO_ASSERT -DLFS_NO_MALLOC -DLFS_NO_DEBUG \
				  -DLFS_NO_WARN -DLFS_NO_ERROR -DLFS_NO_INTRINSICS

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
BSG_FPU_OP=0

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
