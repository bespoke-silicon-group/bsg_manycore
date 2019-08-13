BENCHMARKS = 000.plain
BENCHMARKS+= 000.test
BENCHMARKS+= 175.vpr
BENCHMARKS+= 164.gzip

RUNS = $(patsubst %,%.run,$(BENCHMARKS))

all: checkout
	$(MAKE) $(RUNS)

%.run:
	$(MAKE) -f Makefile.$*
	$(MAKE) -f Makefile.$* clean

checkout:
	git clone git@bitbucket.org:taylor-bsg/greenlight.git 2> /dev/null || (cd greenlight ; git pull)

clean:
	for benchmark in $(BENCHMARKS) ; do \
	$(MAKE) -f Makefile.$$benchmark clean; \
	done;
