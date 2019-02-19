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
proc_exe_logs: X0_Y4.pelog

OBJECT_FILES=main.o bsg_set_tile_x_y.o bsg_printf.o \
			  lfs.o lfs_util.o lfs_bd.o

include ../Makefile.include

LFS_DIR = $(BSG_MANYCORE_DIR)/software/littlefs/lfs # file system
LFS_CONFIG_DIR = $(BSG_MANYCORE_DIR)/software/littlefs
BD_DIR = $(BSG_MANYCORE_DIR)/software/littlefs/bd # block device
vpath %.c $(LFS_DIR) $(BD_DIR)


RISCV_GCC_EXTRA_OPTS = -I$(LFS_DIR) -I$(LFS_CONFIG_DIR) -I$(BD_DIR) \
				  		 -DLFS_NO_MALLOC -DLFS_CONFIG=bsg_lfs_config.h
ifdef DEBUG
RISCV_GCC_EXTRA_OPTS += -O0 -g
else
RISCV_GCC_EXTRA_OPTS += -O1 
RISCV_GCC_EXTRA_OPTS +=-falign-functions  
RISCV_GCC_EXTRA_OPTS +=-falign-jumps 
RISCV_GCC_EXTRA_OPTS +=-falign-labels  
RISCV_GCC_EXTRA_OPTS +=-falign-loops 
RISCV_GCC_EXTRA_OPTS +=-fcaller-saves 
#Error 
#RISCV_GCC_EXTRA_OPTS +=-fcode-hoisting 

RISCV_GCC_EXTRA_OPTS +=-fcrossjumping 
RISCV_GCC_EXTRA_OPTS +=-fcse-follow-jumps  
RISCV_GCC_EXTRA_OPTS +=-fcse-skip-blocks 
RISCV_GCC_EXTRA_OPTS +=-fdelete-null-pointer-checks 
RISCV_GCC_EXTRA_OPTS +=-fdevirtualize  
RISCV_GCC_EXTRA_OPTS +=-fdevirtualize-speculatively 
RISCV_GCC_EXTRA_OPTS +=-fexpensive-optimizations 
RISCV_GCC_EXTRA_OPTS +=-fgcse  

RISCV_GCC_EXTRA_OPTS +=-fgcse-lm  
RISCV_GCC_EXTRA_OPTS +=-fhoist-adjacent-loads 
RISCV_GCC_EXTRA_OPTS +=-finline-small-functions 
RISCV_GCC_EXTRA_OPTS +=-findirect-inlining 
RISCV_GCC_EXTRA_OPTS +=-fipa-bit-cp  
#Error
#RISCV_GCC_EXTRA_OPTS +=-fipa-cp  

RISCV_GCC_EXTRA_OPTS +=-fipa-icf 
RISCV_GCC_EXTRA_OPTS +=-fipa-ra  

RISCV_GCC_EXTRA_OPTS +=-fipa-sra  
RISCV_GCC_EXTRA_OPTS +=-fipa-vrp 
RISCV_GCC_EXTRA_OPTS +=-fisolate-erroneous-paths-dereference 

RISCV_GCC_EXTRA_OPTS +=-flra-remat 
RISCV_GCC_EXTRA_OPTS +=-foptimize-sibling-calls 

RISCV_GCC_EXTRA_OPTS +=-foptimize-strlen 
RISCV_GCC_EXTRA_OPTS +=-fpartial-inlining 

RISCV_GCC_EXTRA_OPTS +=-fpeephole2 
RISCV_GCC_EXTRA_OPTS +=-freorder-blocks-algorithm=stc 

RISCV_GCC_EXTRA_OPTS +=-freorder-blocks-and-partition  
RISCV_GCC_EXTRA_OPTS +=-freorder-functions 

RISCV_GCC_EXTRA_OPTS +=-frerun-cse-after-loop  
RISCV_GCC_EXTRA_OPTS +=-fschedule-insns  
RISCV_GCC_EXTRA_OPTS +=-fschedule-insns2 

RISCV_GCC_EXTRA_OPTS +=-fsched-interblock  
RISCV_GCC_EXTRA_OPTS +=-fsched-spec 
RISCV_GCC_EXTRA_OPTS +=-fstore-merging 
RISCV_GCC_EXTRA_OPTS +=-fstrict-aliasing 

RISCV_GCC_EXTRA_OPTS +=-fthread-jumps 
RISCV_GCC_EXTRA_OPTS +=-ftree-builtin-call-dce 
#Error 
#RISCV_GCC_EXTRA_OPTS +=-ftree-pre 

RISCV_GCC_EXTRA_OPTS +=-ftree-switch-conversion  
RISCV_GCC_EXTRA_OPTS +=-ftree-tail-merge 
RISCV_GCC_EXTRA_OPTS +=-ftree-vrp
endif

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must 
#     be vanilla core 
BSG_FPU_OP=0

main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)


main.o: Makefile

include ../../mk/Makefile.tail_rules
