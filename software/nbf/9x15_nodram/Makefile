include ../../mk/Makefile.paths

TESTS = fib float_math hello quicktouch quicksort float_asm_test nprimes host_dram_access fft

TESTS_RUN = $(addsuffix _run, $(TESTS))

all: $(TESTS_RUN)


%_run:
	mkdir -p $@;
	(cd $@; $(BSG_MACHINE_PATH)/simv +nbf_file=../$*.nbf | tee run.log;)


clean:
	rm -rf $(TESTS_RUN)
