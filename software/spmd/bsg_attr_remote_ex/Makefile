bsg_tiles_X = 1
bsg_tiles_Y = 1
MAX_CYCLES = 10000000

include ../Makefile.include

all: main.run stats/manycore_stats.log

# Build rules: 

# Debug flags for C and C++ so that source is provided inline with assembly
RISCV_GCC_EXTRA_OPTS += -g -ffunction-sections
RISCV_GXX_EXTRA_OPTS += -g -ffunction-sections

OBJECT_FILES += saxpy-c.o saxpy-cpp.o saxpy-cpp-2.o main.o

# saxpy.h contains random arrays for the kernel.
saxpy.h:
	./saxpy.py

$(OBJECT_FILES): saxpy.h

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

stats/manycore_stats.log: main.run
	PYTHONPATH=$(BSG_MANYCORE_DIR)/software/py/ python3 -m vanilla_parser --stats vanilla_stats.csv


# Documentation Rules:

FUNCTIONS=$(shell grep -oh "saxpy_c[a-zA-Z_]*" saxpy-c.h saxpy-cpp.hpp)
docs: snippets $(foreach f,$(FUNCTIONS),snippets/$f.md)

docs-diff: docs
	git diff snippets

snippets:
	mkdir $@

# Replace absolute paths with relative paths
REL=$(shell realpath . --relative-to $(BSG_MANYCORE_DIR))
SED_CMD = "s/\(\/.*\/\)\(bsg_manycore\/.*\)/..\/..\/..\/..\/\2/"


%.md: main.riscv
	@echo \`\`\` > $@
	$(RISCV_BIN_DIR)/riscv32-unknown-elf-dramfs-objdump -M numeric --disassemble=$(notdir $(@:.md=)) -S *.o | sed "/.*$(notdir $(@:.md=))(/,/ret$$/!d" >> $@
	@echo >> $@
	@echo "Command Line Flags: " >> $@
	readelf -p .GCC.command.line $< | sed $(SED_CMD) >> $@
	@echo \`\`\` >> $@

# Clean rules:

local.clean:
	rm -rf saxpy.h
	rm -rf stats

clean: local.clean

extraclean: clean 
	rm -rf snippets

include ../../mk/Makefile.tail_rules

# Include these flags to dump gcc switches in the binary
RISCV_GCC += -frecord-gcc-switches
RISCV_GXX += -frecord-gcc-switches
LLVM_CLANG += -frecord-command-line
