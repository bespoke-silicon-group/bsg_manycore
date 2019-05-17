BENCHMARKS = 000.plain
BENCHMARKS+= 000.test

all: $(patsubst %,%.run,$(BENCHMARKS))

%.run:
	make Makefile.$*
