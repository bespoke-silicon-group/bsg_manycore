bsg_tiles_X = 1
bsg_tiles_Y = 1
MAX_CYCLES = 10000000

include ../Makefile.include

all: main.run stats/manycore_stats.log

# Debug flags for C and C++ so that source is provided inline with assembly
RISCV_GCC_EXTRA_OPTS += -g -ffunction-sections
RISCV_GXX_EXTRA_OPTS += -g -ffunction-sections

OBJECT_FILES += saxpy-c.o saxpy-cpp.o saxpy-cpp-2.o main.o

# saxpy.h contains random arrays for the kernel.
saxpy.h:
	./saxpy.py

# All object files depend on saxpy.h
$(OBJECT_FILES): saxpy.h

main.riscv: $(LINK_SCRIPT) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) $(BSG_MANYCORE_LIB) crt.o
	$(RISCV_LINK) $(OBJECT_FILES) $(SPMD_COMMON_OBJECTS) -L. "-l:$(BSG_MANYCORE_LIB)" -o $@ $(RISCV_LINK_OPTS)

# This target runs the profiler on the output. See the source code for
# examples of calls to the profiler.
stats/manycore_stats.log: main.run
	PYTHONPATH=$(BSG_MANYCORE_DIR)/software/py/ python3 -m vanilla_parser --stats vanilla_stats.csv


# FUNCTIONS contains a list of functions that are defined in the
# .h/.hpp header files. Each function will be disassembled into a
# separate markdown file in the snippets directory.
FUNCTIONS=$(shell grep -oh "saxpy_c[a-zA-Z_]*" saxpy-c.h saxpy-cpp.hpp)

.PHONY: docs docs-diff

# Build the documentation. This is a meta target for building all of
# the snippets found by FUNCTIONS
docs: snippets $(foreach f,$(FUNCTIONS),snippets/$f.md)

# Show differences in the output using git diff
docs-diff: docs
	git diff snippets

# Create the snippets directory
snippets:
	mkdir $@

# Replace absolute paths with relative paths
REL=$(shell realpath . --relative-to $(BSG_MANYCORE_DIR))
SED_CMD = "s/\(\/.*\/\)\(bsg_manycore\/.*\)/..\/..\/..\/..\/\2/"


# Create a markdown file containing the disassembly of a particular
# function that exists within the object files that were used to build
# main.riscv.
#
# The disassembly is injected within backticks (```) so that it
# renders nicely on git and other viewers.
#
# The output file also contains the compilation command line flags.
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
