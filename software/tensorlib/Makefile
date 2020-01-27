SUBDIRS-WITH-MAKE = $(patsubst %/Makefile,%,$(wildcard */Makefile))

.PHONY: all build/%.riscv %-clean clean

all: $(foreach dir, $(SUBDIRS-WITH-MAKE), build/$(dir).riscv)

build/%.riscv:
	$(MAKE) -C $* $*.riscv
	cp $*/$*.riscv $@
	$(MAKE) $*-clean

%-clean:
	$(MAKE) -C $* clean

clean: $(foreach dir,$(SUBDIRS-WITH-MAKE),$(dir)-clean)
	-rm build/*.riscv
