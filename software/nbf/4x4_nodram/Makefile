include ../../mk/Makefile.paths

TESTS = fft fib float_math hello quicktouch nprimes

TESTS_RUN = $(addsuffix _run, $(TESTS))

all: $(TESTS_RUN)


%_run:
	mkdir -p $@;
	(cd $@; $(BSG_MACHINE_PATH)/simv +nbf_file=../$*.nbf | tee run.log)


clean:
	rm -rf $(TESTS_RUN)
