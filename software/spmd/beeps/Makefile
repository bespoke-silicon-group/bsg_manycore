.DEFAULT_GOAL := all

bsg_tiles_X = 1
bsg_tiles_Y = 1

# Include the benchmark list
include Makefile.bmarklist

# Run all benchmarks
all: $(foreach bmark, $(BMARK_LIST), $(bmark).run)

include ../Makefile.include

BEEPS_DIR := $(BSG_MANYCORE_DIR)/imports/beeps/
BUILD_DIR := $(BSG_MANYCORE_DIR)/software/spmd/

install:
	mkdir -p build/
	cd build && $(BEEPS_DIR)/configure --prefix=

include ../../mk/Makefile.tail_rules
