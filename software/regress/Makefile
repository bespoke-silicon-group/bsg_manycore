find-dir-with = $(shell /usr/bin/perl -e 'chomp($$_ = `pwd`); while ($$_ ne "" && ! -e "$$_/$(1)") { m:(.*)/[^/]+/??:; $$_ = $$1; } print;')

ifndef BSG_MANYCORE_DIR
  export BSG_MANYCORE_DIR := $(call find-dir-with,.BSG_MANYCORE_ROOT)
endif

VSCALE_REGRESSION_DIR= $(BSG_MANYCORE_DIR)/imports/vscale/src/test/inputs/

TESTS= $(basename $(notdir $(wildcard $(VSCALE_REGRESSION_DIR)/*.hex)))

$(warning $(TESTS))

landscape: $(foreach x,$(TESTS),$(x).create)

run: $(foreach x,$(wildcard test.*),$(x).regress)

%.regress: 
	make -C $* TEE=1

%.create:
	mkdir test.$(subst -,_,$*)
	cp $(VSCALE_REGRESSION_DIR)/$*.hex test.$(subst -,_,$*)/$(subst -,_,$*).hex
	cp Makefile.base test.$(subst -,_,$*)/Makefile

clean:
	rm -rf test.*



