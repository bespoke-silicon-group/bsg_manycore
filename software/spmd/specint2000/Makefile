BENCHMARKS = 000.test
BENCHMARKS+= 164.gzip
BENCHMARKS+= 175.vpr
BENCHMARKS+= 181.mcf
#BENCHMARKS+= 186.crafty
BENCHMARKS+= 197.parser
BENCHMARKS+= 256.bzip2
#BENCHMARKS+= 300.twolf

RUNS = $(patsubst %,%.run,$(BENCHMARKS))

all: checkout
	$(MAKE) $(RUNS)

%.run:
	$(MAKE) -f Makefile.$*
	$(MAKE) -f Makefile.$* clean

%.dis:
	$(MAKE) -f Makefile.$* $*.dis
checkout:
	git clone git@bitbucket.org:taylor-bsg/greenlight.git 2> /dev/null || (cd greenlight ; git pull)

clean:
	for benchmark in $(BENCHMARKS) ; do \
	$(MAKE) -f Makefile.$$benchmark clean; \
	done;

include ../../../../bsg_cadenv/cadenv.mk
dve:
	$(DVE) -full64 -vpd vcdplus.vpd &
