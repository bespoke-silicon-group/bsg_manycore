BENCHMARKS = 000.plain
BENCHMARKS+= 000.test

RUNS = $(patsubst %,%.run,$(BENCHMARKS))

all: $(RUNS)

%.run:
	make -f Makefile.$*
	make -f Makefile.$* clean

clean:
	for benchmark in $(BENCHMARKS) ; do \
	make -f Makefile.$$benchmark clean; \
	done;
