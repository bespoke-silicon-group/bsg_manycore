include ../Makefile.include

bsg_tiles_Y = 2
bsg_tiles_X = 2

BLACKPARROT_SDK_DIR   := $(BSG_MANYCORE_DIR)/../black-parrot-sdk
BLACKPARROT_SRC_FILES := bp_crt.S bp_utils.c bp_main.c
BLACKPARROT_LINKER    := bp_linker

OBJECT_FILES=main.o

RISCV64_GCC     := $(BLACKPARROT_SDK_DIR)/install/bin/riscv64-unknown-elf-dramfs-gcc
RISCV64_OBJDUMP := $(BLACKPARROT_SDK_DIR)/install/bin/riscv64-unknown-elf-dramfs-objdump -D
RISCV64_OBJCOPY := $(BLACKPARROT_SDK_DIR)/install/bin/riscv64-unknown-elf-dramfs-objcopy -O verilog --verilog-data-width 4

CURR_DIR = $(shell pwd)

RISCV_GCC_OPTS += -fno-delete-null-pointer-checks
RISCV64_GCC_OPTS = -march=rv64imafd -mabi=lp64 -mcmodel=medany -I$(CURR_DIR) -T$(BLACKPARROT_LINKER) -nostartfiles

all: main.run

prog.riscv64:
	$(RISCV64_GCC) -o $@ $(BLACKPARROT_SRC_FILES) $(RISCV64_GCC_OPTS)

prog.dis: prog.riscv64
	$(RISCV64_OBJDUMP) $^

prog.mem: prog.riscv64
	$(RISCV64_OBJCOPY) $< $@

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o prog.mem
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

main.o: Makefile

clean.bp_manycore:
	rm -f *.mem
	rm -f *.riscv64

clean: clean.bp_manycore

include ../../mk/Makefile.tail_rules
