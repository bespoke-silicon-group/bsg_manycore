# NOT INCLUDED IN NORMAL MAKEFILE -----
TOOL_ROOT=/mnt/bsg/diskbits/neilryan
RV_TOOLCHAIN=$(TOOL_ROOT)/local
RVCC=/mnt/bsg/diskbits/neilryan/llvm/llvm-install/bin/clang
LINK=$(RVCC) -T $(BSG_SOFTWARE)/spmd/common/test.ld

INC_DIR=$(RV_TOOLCHAIN)/include
GCC_OPTS=-march=rv32ima -mabi=ilp32 -I $(INC_DIR) -static -std=gnu99 -ffast-math -fno-common -fno-builtin-printf -O2 -I $(BSG_SOFTWARE)/spmd/common -I $(BSG_SOFTWARE)/bsg_manycore_lib
LINK_OPTS=-march=rv32ima -mabi=ilp32 -nostdlib -nostartfiles -ffast-math -lc -lgcc -L $(BSG_SOFTWARE)/spmd/common

SPMD_DEFS=-Dbsg_tiles_X=2 -Dbsg_tiles_Y=2 -DPREALLOCATE=0 -DHOST_DEBUG=0
INCS=
PASS_FILE=~/llvm-pass-skeleton/build/skeleton/libSkeletonPass.so
INC_PASS=-Xclang -load -Xclang $(PASS_FILE)

%.o: %.c
	$(RVCC) $(GCC_OPTS) $(INC_PASS) $(SPMD_DEFS) -c $(INCS) $< -o $@

bsg_set_tile_x_y.o: ../../bsg_manycore_lib/bsg_set_tile_x_y.c
	$(RVCC) $(GCC_OPTS) $(SPMD_DEFS) -c $(INCS) $< -o $@
# NOT INC IN NORMAL MAKEFILE -----

bsg_tiles_X = 2
bsg_tiles_Y = 2

#########################################################
#each bytes defines the core type
# 00: vanilla core
# 01  vscale  core
#TYPE_VEC="64'h01_01_01_01"

all: main.run
OBJECT_FILES=main.o bsg_set_tile_x_y.o

include ../Makefile.include

#########################################################
#            FPU OPTION
#     The number of horizon node must be two and must
#     be vanilla core
BSG_FPU_OP=0

$(warning LINKER=$(RISCV_LINK))
$(warning RVCC=$(RVCC))
main.riscv: $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) ../common/crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

include ../../mk/Makefile.tail_rules
